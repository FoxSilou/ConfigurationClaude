---
description: "Domain Event pattern — sealed record, IDomainEvent, Creer factory, time as parameter"
globs: ["**/Domain/**/*.cs", "**/Events/**/*.cs"]
---

# Rule: Domain Event Pattern

## Core Principle

Domain Events signal significant state changes in the domain. They are raised by aggregate roots and dispatched after persistence. They are **facts** — something that happened in the past.

## Structure

```csharp
public sealed record <EventName>(
    <TypedId> <AggregateId>,
    <ValueObject> <RelevantData>,
    DateTimeOffset OccurredOn) : IDomainEvent
{
    public static <EventName> Creer(<TypedId> id, <ValueObject> data, DateTimeOffset maintenant)
        => new(id, data, maintenant);
}
```

## Rules

- Domain events are `sealed record` types implementing `IDomainEvent`.
- **Naming**: French past participle + noun, no suffix. E.g., `PartieCree`, `UtilisateurInscrit`, `CommandeAnnulee`.
- **`OccurredOn` is always `DateTimeOffset`** — never `DateTime`.
- **No system clock**: events never call `DateTimeOffset.UtcNow` or any clock directly. The time is always provided as a `DateTimeOffset maintenant` parameter from the caller (aggregate or handler via `TimeProvider`).
- **Factory method `Creer`**: events use a static factory to make time injection explicit.
- Events carry **only the data needed by consumers** — minimal payload, use Value Objects and Typed Ids, not primitives.
- Events live in `Domain/Events/` within each Bounded Context.
- Events are **immutable** — records guarantee this.

## Raising Events

Events are raised in **business factory methods** and **behavior methods** of aggregate roots:

```csharp
// In the aggregate root
public static Partie Creer(PartieId id, NomDePartie nom, DateTimeOffset maintenant)
{
    var partie = new Partie(id, nom);
    partie.RaiseDomainEvent(PartieCree.Creer(id, nom, maintenant));
    return partie;
}
```

**`Reconstituer` never raises events** — reconstituting from persistence is not a business action.

## Dispatching Events

Events are collected in the aggregate via `RaiseDomainEvent()` (inherited from `AggregateRoot<TId>`) and dispatched **after successful persistence** by infrastructure code (e.g., EF Core SaveChanges interceptor or a MediatR pipeline behavior). After dispatch, `ClearDomainEvents()` is called.

## Testing Events

```csharp
// Assert that the correct event was raised
var partie = Partie.Creer(id, nom, maintenant);
partie.DomainEvents.Should().ContainSingle()
    .Which.Should().BeOfType<PartieCree>()
    .Which.PartieId.Should().Be(id);
```

## Full Example

```csharp
public sealed record PartieCree(
    PartieId PartieId,
    NomDePartie Nom,
    DateTimeOffset OccurredOn) : IDomainEvent
{
    public static PartieCree Creer(PartieId id, NomDePartie nom, DateTimeOffset maintenant)
        => new(id, nom, maintenant);
}
```

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Domain event | French past participle + noun | `PartieCree`, `UtilisateurInscrit` |
| Factory method | `Creer` | `PartieCree.Creer(id, nom, maintenant)` |
| Time parameter | `maintenant` (`DateTimeOffset`) | Always injected, never from system clock |
| Directory | `Domain/Events/` | One file per event |


---
