---
description: "MediatR as infrastructure adapter — NEVER referenced in Domain or Application"
alwaysApply: true
globs: ["**/Infrastructure/**/*.cs", "**/Api/**/*.cs"]
---

# Rule: MediatR as Infrastructure Adapter

## Core Principle

**MediatR is an infrastructure detail.** It must NEVER be referenced in the Domain or Application layers. The generic interfaces `ICommand<T>`, `IQuery<T>`, `ICommandHandler<TCommand, TResult>`, `IQueryHandler<TQuery, TResult>`, `ICommandBus`, `IQueryBus` are defined in **SharedKernel**. The MediatR adapter in Infrastructure bridges them.

## ⚠️ NON-NEGOTIABLE RULE

```
Domain         → NO MediatR reference
Application    → NO MediatR reference (uses ICommand, IQuery, ICommandHandler, IQueryHandler)
SharedKernel   → NO MediatR reference (defines ICommandBus, IQueryBus, etc.)
Infrastructure → YES — MediatR adapters, pipeline behaviors, DI registration
Api            → Acceptable — Composition root, uses ISender to dispatch (or use ICommandBus port)
```

**No file** in Domain, Application, or SharedKernel must contain `using MediatR`.

## Generic Interfaces (SharedKernel)

```csharp
// Defined in SharedKernel — NO MediatR dependency
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

## MediatR Adapter (Infrastructure)

The adapter wraps our generic interfaces to make them compatible with MediatR's `IRequest`/`IRequestHandler`:

```csharp
// Infrastructure — this is the ONLY place MediatR types appear
using MediatR;

internal sealed class MediatRCommandAdapter<TCommand, TResult>(
    ICommandHandler<TCommand, TResult> handler)
    : IRequestHandler<MediatRCommandWrapper<TCommand, TResult>, TResult>
    where TCommand : ICommand<TResult>
{
    public Task<TResult> Handle(
        MediatRCommandWrapper<TCommand, TResult> request,
        CancellationToken ct)
        => handler.HandleAsync(request.Command, ct);
}

internal sealed record MediatRCommandWrapper<TCommand, TResult>(TCommand Command)
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
| **SharedKernel** | ❌ NEVER | ICommand, IQuery, ICommandBus, IQueryBus (our own interfaces) |
| **Application** | ❌ NEVER | ICommandHandler, IQueryHandler implementations |
| **Infrastructure** | ✅ YES | MediatR adapters, pipeline behaviors, DI registration |
| **Api** | ✅ Acceptable | Composition root, uses ICommandBus (or ISender if not using the port) |


---
