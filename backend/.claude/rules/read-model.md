---
description: "Read model and Query side conventions — projections, read DTOs, read repositories"
alwaysApply: false
globs: ["**/Read/**/*.cs"]
---

# Rule: Read Model

## Core Principle

The Read side is optimized for **query performance and simplicity**. It does not go through aggregates or domain entities — it reads data directly from the store via lightweight read models or projections.

## Structure

```
src/<BoundedContext>/Read/
├── Application/
│   ├── <QueryFiles>.cs        ← Queries + nested handlers (flat, no Queries/ subfolder)
│   └── Ports/                 ← Read-specific service interfaces
├── Infrastructure/
│   ├── Configurations/         ← IEntityTypeConfiguration<T> for each read model (registered in shared ReadDbContext)
│   └── <ReadRepository>.cs    ← Read repository implementations (EF Core, Dapper…)
└── Api/
    └── <ReadEndpoints>.cs     ← Read endpoints (GET)
```

## Read Models

Read models are **flat DTOs** optimized for the consumer (API response, UI). They are not domain objects.

```csharp
// Read model — simple record, no behavior, no invariants
public sealed record PartieDto(Guid Id, string Nom, string Statut, int NombreDeJoueurs);

// Collection read model
public sealed record PartieListeDto(IReadOnlyCollection<PartieResumeDto> Parties, int Total);
public sealed record PartieResumeDto(Guid Id, string Nom, string Statut);
```

### Rules

- Read models are `sealed record` types — immutable, no behavior.
- They use **primitives** (not Value Objects) — they are for the outside world, not for the domain.
- They are named with the `Dto` suffix in French: `PartieDto`, `JoueurResumeDto`.
- They live in `Read/Application/` alongside the queries.

## Read Repositories / Data Access

The Read side can bypass domain repositories entirely:

```csharp
// Option 1: Dedicated read repository interface
public interface IPartieReadRepository
{
    Task<PartieDto?> ObtenirParIdAsync(Guid id, CancellationToken ct = default);
    Task<PartieListeDto> ListerAsync(int page, int taille, CancellationToken ct = default);
}

// Option 2: Direct DbContext access in the handler (for simple queries)
public sealed record ObtenirPartie(Guid PartieId) : IQuery<PartieDto>
{
    public sealed class Handler(ReadDbContext db) : IQueryHandler<ObtenirPartie, PartieDto>
    {
        public async Task<PartieDto> HandleAsync(ObtenirPartie requete, CancellationToken ct = default)
        {
            var partie = await db.Parties
                .Where(p => p.Id == requete.PartieId)
                .Select(p => new PartieDto(p.Id, p.Nom, p.Statut, p.Joueurs.Count))
                .FirstOrDefaultAsync(ct)
                ?? throw new NotFoundException($"Partie {requete.PartieId} introuvable.");
            return partie;
        }
    }
}
```

### When to use which

| Approach | When |
|---|---|
| Read repository interface | Complex queries, reusable across multiple queries, needs testability |
| Direct DbContext in handler | Simple single-use queries, performance-critical with specific projections |
| Dapper | High-performance reads, complex SQL, reporting |

## Rules

- **Queries never modify state** — no writes, no events, no side effects.
- **Queries never return domain entities** — always DTOs or read models.
- **Read side is independent from Write side** — it does not reference Write domain objects or repositories.
- **No domain validation in queries** — if the data is in the store, it is valid.
- Read repositories can use `IQueryable<T>` internally (unlike Write repositories which must not expose it).

## Bootstrap du schéma Read

- Les tables de read models doivent être matérialisées au démarrage via `ReadDatabaseSeeder.EnsureReadDatabaseAsync(IServiceProvider, CancellationToken)` dans `Shared.Read.Infrastructure/`.
- Le seeder utilise `IRelationalDatabaseCreator.CreateTablesAsync()` (**pas** `EnsureCreatedAsync`) car le `ReadDbContext` **partage la base** avec `AppIdentityDbContext` — `EnsureCreatedAsync` serait no-op si la base existe déjà (créée par `IdentityDataSeeder`), laissant les tables de read models non créées.
- Tolérer l'erreur SQL Server `2714` ("There is already an object named …") : au redémarrage à chaud, les tables existent déjà — silence attendu.
- Câblage dans `Program.cs`, dans le scope `if (!app.Environment.IsEnvironment("Build"))`, **après** `IdentityDataSeeder.EnsureIdentityDatabaseAsync` (base créée + tables Identity posées) pour que `CreateTablesAsync` n'ait qu'à ajouter les tables du modèle Read.
- Ne jamais utiliser `MigrateAsync` (piège OpenAPI build-time — pas de base au build).

### Symptôme si omis

```
SqlException (0x80131904): Nom d'objet 'Utilisateurs' non valide.
  at Microsoft.EntityFrameworkCore.Update.ReaderModificationCommandBatch.ExecuteAsync…
```

Déclenché dès la première projection écrivant dans une table Read.


---
