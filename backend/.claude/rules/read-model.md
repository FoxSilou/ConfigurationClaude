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
│   ├── ReadDbContext.cs        ← Dedicated read DbContext (or shared, depending on scale)
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


---
