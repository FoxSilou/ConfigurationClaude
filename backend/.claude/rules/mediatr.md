---
description: "MediatR as infrastructure adapter — NEVER referenced in Domain or Application"
alwaysApply: true
globs: ["**/Infrastructure/**/*.cs", "**/Api/**/*.cs"]
---

# Rule: MediatR as Infrastructure Adapter

## Core Principle

**MediatR is an infrastructure detail.** It must NEVER be referenced in the Domain or Application layers. The generic interfaces `ICommand<T>`, `IQuery<T>`, `ICommandHandler<TCommand, TResult>`, `IQueryHandler<TQuery, TResult>`, `ICommandBus`, `IQueryBus` are defined in **Shared.Write.Domain**. The MediatR adapter in Infrastructure bridges them.

## ⚠️ NON-NEGOTIABLE RULE

```
Domain         → NO MediatR reference
Application    → NO MediatR reference (uses ICommand, IQuery, ICommandHandler, IQueryHandler)
Shared.Write.Domain   → NO MediatR reference (defines ICommandBus, IQueryBus, etc.)
Shared.Write.Infrastructure → YES — MediatR command adapters, pipeline behaviors, AddWriteMessaging()
Shared.Read.Infrastructure  → YES — MediatR query adapters, AddReadMessaging()
BC Infrastructure → YES — DI registration
Api            → Acceptable — Composition root, uses ICommandBus/IQueryBus (or ISender if not using the port)
```

**No file** in Domain, Application, or Shared.Write.Domain must contain `using MediatR`.

## Generic Interfaces (Shared.Write.Domain)

```csharp
// Defined in Shared.Write.Domain — NO MediatR dependency
public interface ICommand<TResult> { }
public interface ICommandHandler<in TCommand, TResult> where TCommand : ICommand<TResult>
{
    Task<TResult> HandleAsync(TCommand commande, CancellationToken ct = default);
}

public interface IQuery<TResult> { }
public interface IQueryHandler<in TQuery, TResult> where TQuery : IQuery<TResult>
{
    Task<TResult> HandleAsync(TQuery requete, CancellationToken ct = default);
}

public interface ICommandBus
{
    Task<TResult> EnvoyerAsync<TCommand, TResult>(TCommand commande, CancellationToken ct = default)
        where TCommand : ICommand<TResult>;
}
```

## MediatR Adapters (Infrastructure)

Command and Query adapters are **split across two Shared Infrastructure projects** to respect CQRS:

- **Shared.Write.Infrastructure** — command adapters: `CommandRequest`, `CommandRequestHandler`, `VoidCommandRequestHandler`, `MediatRCommandBus`, `AddWriteMessaging()`
- **Shared.Read.Infrastructure** — query adapters: `QueryRequest`, `QueryRequestHandler`, `MediatRQueryBus`, `AddReadMessaging()`

```csharp
// Shared.Write.Infrastructure — command adapter
using MediatR;

internal sealed class CommandRequestHandler<TCommand, TResult>(
    ICommandHandler<TCommand, TResult> handler)
    : IRequestHandler<CommandRequest<TCommand, TResult>, TResult>
    where TCommand : ICommand<TResult>
{
    public Task<TResult> Handle(
        CommandRequest<TCommand, TResult> request,
        CancellationToken ct)
        => handler.HandleAsync(request.Command, ct);
}

internal sealed record CommandRequest<TCommand, TResult>(TCommand Command)
    : IRequest<TResult>
    where TCommand : ICommand<TResult>;
```

## API Layer — Dispatching

The API layer uses `ICommandBus` (our abstraction) to dispatch commands:

```csharp
app.MapPost("/api/parties", async (CreerPartieRequest request, ICommandBus commandBus, CancellationToken ct) =>
{
    var commande = new CreerPartie(request.Nom);
    var id = await commandBus.EnvoyerAsync<CreerPartie, PartieId>(commande, ct);
    return Results.Created($"/api/parties/{id.Valeur}", new { Id = id.Valeur });
});
```

## What Goes Where

| Layer | MediatR reference | Role |
|---|---|---|
| **Domain** | ❌ NEVER | Domain model, no technical dependencies |
| **Shared.Write.Domain** | ❌ NEVER | ICommand, IQuery, ICommandBus, IQueryBus (our own interfaces) |
| **Application** | ❌ NEVER | ICommandHandler, IQueryHandler implementations |
| **Shared.Write.Infrastructure** | ✅ YES | MediatR command adapters, pipeline behaviors, AddWriteMessaging() |
| **Shared.Read.Infrastructure** | ✅ YES | MediatR query adapters, AddReadMessaging() |
| **BC Infrastructure** | ✅ YES | DI registration |
| **Api** | ✅ Acceptable | Composition root, uses ICommandBus/IQueryBus |


---
