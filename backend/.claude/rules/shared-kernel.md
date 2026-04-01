---
description: "SharedKernel — shared abstractions across bounded contexts (AggregateRoot, ICommand, IQuery, ICommandBus)"
alwaysApply: true
globs: ["**/SharedKernel/**/*.cs"]
---

# Rule: SharedKernel

## Core Principle

The SharedKernel contains **shared abstractions** used across multiple Bounded Contexts. It is the only cross-cutting project in the solution. It has **zero external dependencies** — no MediatR, no EF Core, no third-party packages.

## What Lives in SharedKernel

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

### Shared Domain Exceptions

```csharp
// Exceptions/DomainException.cs
public class DomainException : Exception
{
    public DomainException(string message) : base(message) { }
}

// Exceptions/NotFoundException.cs
public class NotFoundException : DomainException
{
    public NotFoundException(string message) : base(message) { }
}
```

## Rules

- **Zero external dependencies** — SharedKernel references no NuGet packages. It is pure C#.
- **No MediatR** — `ICommand`, `IQuery`, `ICommandBus`, `IQueryBus` are our own interfaces. MediatR adapters live in Infrastructure.
- **No business logic** — SharedKernel provides abstractions and base types, not domain-specific behavior.
- **All Bounded Contexts may reference SharedKernel** — but SharedKernel references nothing else.
- **Stable contracts** — changes to SharedKernel affect all BCs, so abstractions must be stable.

## Directory Structure

```
src/SharedKernel/
├── AggregateRoot.cs
├── IAggregateRoot.cs
├── IDomainEvent.cs
├── Abstractions/
│   ├── ICommand.cs
│   ├── ICommandBus.cs
│   ├── IQuery.cs
│   └── IQueryBus.cs
└── Exceptions/
    ├── DomainException.cs
    └── NotFoundException.cs
```


---
