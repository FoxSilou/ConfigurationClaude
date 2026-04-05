---
description: "Shared.Write.Domain — shared abstractions across bounded contexts (AggregateRoot, ICommand, IQuery, ICommandBus, IEventStore, IDomainEventHandler, IDomainEventBus, ITypedId)"
alwaysApply: true
globs: ["**/Shared.Write.Domain/**/*.cs", "**/Shared/Write/**/*.cs"]
---

# Rule: Shared.Write.Domain (formerly SharedKernel)

## Core Principle

`Shared.Write.Domain` contains **shared abstractions** used across multiple Bounded Contexts. It is the only cross-cutting domain project in the solution. It has **zero external dependencies** — no MediatR, no EF Core, no third-party packages.

## What Lives in Shared.Write.Domain

### Domain Base Types

```csharp
// IDomainEvent.cs
public interface IDomainEvent
{
    DateTimeOffset OccurredOn { get; }
}

// IAggregateRoot.cs
public interface IAggregateRoot
{
    IReadOnlyCollection<IDomainEvent> DomainEvents { get; }
    void ClearDomainEvents();
}

// AggregateRoot.cs
public abstract class AggregateRoot<TId> : IAggregateRoot where TId : notnull
{
    private readonly List<IDomainEvent> _domainEvents = [];

    public TId Id { get; protected set; } = default!;
    public IReadOnlyCollection<IDomainEvent> DomainEvents => _domainEvents.AsReadOnly();

    protected void RaiseDomainEvent(IDomainEvent domainEvent) => _domainEvents.Add(domainEvent);
    public void ClearDomainEvents() => _domainEvents.Clear();
}

// ITypedId.cs — contract for Typed Id JSON serialization
public interface ITypedId<out TPrimitive>
{
    TPrimitive Valeur { get; }
}
```

### CQRS Abstractions (NO MediatR dependency)

```csharp
// Abstractions/ICommand.cs
public interface ICommand;
public interface ICommand<TResult>;

public interface ICommandHandler<in TCommand> where TCommand : ICommand
{
    Task HandleAsync(TCommand commande, CancellationToken ct = default);
}
public interface ICommandHandler<in TCommand, TResult> where TCommand : ICommand<TResult>
{
    Task<TResult> HandleAsync(TCommand commande, CancellationToken ct = default);
}

// Abstractions/ICommandBus.cs
public interface ICommandBus
{
    Task<TResult> EnvoyerAsync<TCommand, TResult>(TCommand commande, CancellationToken ct = default)
        where TCommand : ICommand<TResult>;
    Task EnvoyerAsync<TCommand>(TCommand commande, CancellationToken ct = default)
        where TCommand : ICommand;
}

// Abstractions/IQuery.cs
public interface IQuery<TResult>;

public interface IQueryHandler<in TQuery, TResult> where TQuery : IQuery<TResult>
{
    Task<TResult> HandleAsync(TQuery requete, CancellationToken ct = default);
}

// Abstractions/IQueryBus.cs
public interface IQueryBus
{
    Task<TResult> EnvoyerAsync<TQuery, TResult>(TQuery requete, CancellationToken ct = default)
        where TQuery : IQuery<TResult>;
}
```

### Event Sourcing Abstractions

```csharp
// Abstractions/IEventStore.cs
public interface IEventStore
{
    Task AppendToStreamAsync(string streamId, IReadOnlyCollection<IDomainEvent> events, int expectedVersion, CancellationToken ct = default);
    Task<IReadOnlyCollection<IDomainEvent>> ReadStreamAsync(string streamId, int fromVersion = 0, CancellationToken ct = default);
    Task<Snapshot?> LoadSnapshotAsync(string streamId, CancellationToken ct = default);
    Task SaveSnapshotAsync(string streamId, int version, object state, CancellationToken ct = default);
}

public sealed record Snapshot(int Version, object State);

// Abstractions/IDomainEventHandler.cs
public interface IDomainEventHandler<in TEvent> where TEvent : IDomainEvent
{
    Task HandleAsync(TEvent @event, CancellationToken ct = default);
}

// Abstractions/IDomainEventBus.cs
public interface IDomainEventBus
{
    Task PublierAsync(IReadOnlyCollection<IDomainEvent> events, CancellationToken ct = default);
}
```

### Shared Domain Exceptions

```csharp
// Exceptions/DomainException.cs
public class DomainException(string message) : Exception(message);

// Exceptions/NotFoundException.cs
public class NotFoundException(string message) : DomainException(message);
```

## Rules

- **Zero external dependencies** — Shared.Write.Domain references no NuGet packages. It is pure C#.
- **No MediatR** — `ICommand`, `IQuery`, `ICommandBus`, `IQueryBus` are our own interfaces. MediatR command adapters live in Shared.Write.Infrastructure, query adapters in Shared.Read.Infrastructure.
- **No business logic** — Shared.Write.Domain provides abstractions and base types, not domain-specific behavior.
- **All Bounded Contexts may reference Shared.Write.Domain** — but Shared.Write.Domain references nothing else.
- **Stable contracts** — changes to Shared.Write.Domain affect all BCs, so abstractions must be stable.

## Directory Structure

```
src/Shared/Write/Shared.Write.Domain.csproj
├── AggregateRoot.cs
├── IAggregateRoot.cs
├── IDomainEvent.cs
├── ITypedId.cs
├── Abstractions/
│   ├── ICommand.cs
│   ├── ICommandBus.cs
│   ├── IQuery.cs
│   ├── IQueryBus.cs
│   ├── IEventStore.cs
│   ├── IDomainEventHandler.cs
│   └── IDomainEventBus.cs
└── Exceptions/
    ├── DomainException.cs
    └── NotFoundException.cs
```


---
