---
description: "Aggregate Root pattern — AggregateRoot<TId> base class, domain event collection, business/persistence factories"
globs: ["**/Domain/**/*.cs", "**/Aggregates/**/*.cs"]
---

# Rule: Aggregate Root Pattern

## Core Principle

All aggregate roots inherit from `AggregateRoot<TId>` and implement `IAggregateRoot`. This abstract base class provides domain event collection and dispatch, and shared aggregate behavior (equality by Id, etc.).

The base class and interface live in **SharedKernel** (shared across Bounded Contexts).

## Base Types

```csharp
// SharedKernel
public interface IDomainEvent
{
    DateTimeOffset OccurredOn { get; }
}

public interface IAggregateRoot
{
    IReadOnlyCollection<IDomainEvent> DomainEvents { get; }
    void ClearDomainEvents();
}

public abstract class AggregateRoot<TId> : IAggregateRoot where TId : notnull
{
    private readonly List<IDomainEvent> _domainEvents = [];

    public TId Id { get; protected set; } = default!;
    public IReadOnlyCollection<IDomainEvent> DomainEvents => _domainEvents.AsReadOnly();

    protected void RaiseDomainEvent(IDomainEvent domainEvent) => _domainEvents.Add(domainEvent);
    public void ClearDomainEvents() => _domainEvents.Clear();
}
```

## Aggregate Structure

```csharp
public sealed class Utilisateur : AggregateRoot<UtilisateurId>
{
    // ⚠️ Invariants validated in the private constructor
    private Utilisateur(UtilisateurId id, AdresseEmail email, ...)
    {
        ArgumentNullException.ThrowIfNull(email);
        Id = id;
        Email = email;
    }

    public AdresseEmail Email { get; private set; }

    // Business factory — raises domain events
    public static Utilisateur Inscrire(UtilisateurId id, AdresseEmail email, ...)
    {
        var utilisateur = new Utilisateur(id, email, ...);
        utilisateur.RaiseDomainEvent(new UtilisateurInscrit(id, email));
        return utilisateur;
    }

    // Persistence factory — no events
    internal static Utilisateur Reconstituer(UtilisateurId id, AdresseEmail email, ...)
    {
        return new Utilisateur(id, email, ...);
    }
}
```

## Rules

- **Every aggregate root** inherits from `AggregateRoot<TId>` — no aggregate without this base class.
- **Domain events are raised** via `RaiseDomainEvent()` in business factory methods and behavior methods.
- **`Reconstituer` does NOT raise events** — reconstituting from persistence is not a business action.
- **Events are dispatched after persistence** — the infrastructure (e.g., EF Core SaveChanges interceptor or MediatR pipeline) reads `DomainEvents`, dispatches them, then calls `ClearDomainEvents()`.
- **Invariants in the private constructor** — the base class does not validate, each concrete aggregate validates its own invariants in its private constructor.
- Aggregates live in the `Aggregates/` directory of each Bounded Context's Domain layer.

## Directory Structure

```
src/<BoundedContext>/Write/Domain/
├── Aggregates/
│   └── Utilisateur.cs
├── Entities/
│   └── ...
├── ValueObjects/
│   ├── AdresseEmail.cs
│   ├── MotDePasseHash.cs
│   └── TokenDeConfirmation.cs
├── Events/
│   └── UtilisateurInscrit.cs
└── Ports/
    └── IUtilisateurRepository.cs
```

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Aggregate base class | `AggregateRoot<TId>` | `AggregateRoot<UtilisateurId>` |
| Aggregate interface | `IAggregateRoot` | Implemented by `AggregateRoot<TId>` |
| Domain event interface | `IDomainEvent` | `public interface IDomainEvent` |
| Domain event | French past participle + noun | `UtilisateurInscrit`, `PartieCree` |
| Raise event method | `RaiseDomainEvent` | `RaiseDomainEvent(new ...)` |


---
