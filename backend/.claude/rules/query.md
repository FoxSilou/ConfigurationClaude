---
description: "Query pattern — sealed record + nested Handler, IQuery<T> (no MediatR in Application)"
globs: ["**/Application/**/*.cs", "**/Read/**/*.cs"]
---

# Rule: Query Pattern

## Structure

A query and its handler are always in the **same file**, with the handler as a **nested class** inside the query. This mirrors the Command pattern.

**⚠️ RÈGLE CRITIQUE**: `IQuery<T>` et `IQueryHandler<TQuery, TResult>` sont des **interfaces génériques définies dans SharedKernel**. Elles ne référencent **JAMAIS** MediatR. MediatR est un détail d'infrastructure. Ni le Query, ni le Handler ne doivent avoir de `using MediatR`.

Queries live in the **Read stack** (`Read/Application/`), separate from the Write stack. They are placed flat (no `Queries/` subfolder).

```csharp
// ⚠️ NO `using MediatR` here — IQuery/IQueryHandler are OUR interfaces
public sealed record <QueryName>(<Parameters>) : IQuery<<ReturnType>>
{
    public sealed class Handler(<Dependencies>) : IQueryHandler<<QueryName>, <ReturnType>>
    {
        public Task<<ReturnType>> HandleAsync(<QueryName> requete, CancellationToken ct = default)
        {
            // 1. Fetch data via read port or direct read model
            // 2. Map to DTO / read model
            // 3. Return
        }
    }
}
```

## Rules

- The query is a `sealed record`.
- The handler is a `sealed class` nested inside the query.
- Dependencies are injected via **primary constructor** on the handler.
- The query name follows the **ubiquitous language** in French (domain language).
- The query parameter is named `requete` in `HandleAsync`.
- A query **never** modifies state — no write operations, no domain events.
- Queries can bypass domain repositories and query the read model / DbContext directly for performance.
- Return types are dedicated DTOs or read models, **never** domain entities.
- **⚠️ Aucune référence à MediatR** dans ce fichier. `IQuery<T>` et `IQueryHandler<TQuery, TResult>` sont nos propres interfaces.

## Example

```csharp
public sealed record ObtenirPartie(Guid PartieId) : IQuery<PartieDto>
{
    public sealed class Handler(IPartieReadRepository repository) : IQueryHandler<ObtenirPartie, PartieDto>
    {
        public async Task<PartieDto> HandleAsync(ObtenirPartie requete, CancellationToken ct = default)
        {
            var id = PartieId.Reconstituer(requete.PartieId);
            var partie = await repository.ObtenirParIdAsync(id, ct)
                ?? throw new NotFoundException($"Partie {requete.PartieId} introuvable.");

            return partie;
        }
    }
}
```

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Query | French infinitive verb + noun, **no** suffix | `ObtenirPartie`, `ListerJoueurs`, `RechercherParties` |
| Nested handler | Always `Handler` | `public sealed class Handler(...)` |
| Handler parameter | `requete` | `HandleAsync(ObtenirPartie requete, ...)` |
| Return type | Dedicated DTO | `PartieDto`, `IReadOnlyCollection<JoueurDto>` |
| DTO | French noun + `Dto` suffix | `PartieDto`, `JoueurDto` |


---
