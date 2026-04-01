---
name: scaffold-architecture
description: >
  Backend infrastructure architecture rules for scaffolding.
  Covers: CQRS read/write stack separation, MediatR as infrastructure adapter,
  dispatch architecture (ICommandBus -> MediatRCommandBus -> Handler),
  automatic handler registration via AddMessaging(), API endpoint conventions,
  DateTimeOffset + TimeProvider, ports with Value Objects, Reconstituer() pattern,
  AggregateRoot<TId> base class.
  Use when scaffolding backend infrastructure or wiring vertical slices.
user-invocable: false
---

# Skill: Scaffold Architecture — Backend Infrastructure Rules

These rules are NON-NEGOTIABLE when writing backend infrastructure code.

---

## CQRS — Separate Read / Write Stacks

The project follows **strict CQRS**. Each bounded context has separate Read and Write stacks across all layers. See rule `cqrs.md`.

```
src/<BoundedContext>/
├── Write/
│   ├── Domain/       (Aggregates/, Entities/, ValueObjects/, Events/, Ports/)
│   ├── Application/  (<CommandFiles>.cs flat, Behaviors/, Ports/)
│   ├── Infrastructure/
│   └── Api/
└── Read/
    ├── Application/  (<QueryFiles>.cs flat, Ports/)
    ├── Infrastructure/
    └── Api/
```

When scaffolding a BC, create BOTH stacks (even if Read side is empty initially).

---

## MediatR Is an Infrastructure Detail — NEVER in Domain or Application

MediatR lives **exclusively** in Infrastructure. See rule `mediatr.md`.

- **`ICommand<T>`**, **`ICommandHandler<TCommand, TResult>`**, **`ICommand`**, **`ICommandHandler<TCommand>`** are generic interfaces defined in `SharedKernel/Abstractions/`. They have **zero dependency on MediatR**.
- **`ICommandBus`** is defined in `SharedKernel/Abstractions/`. This is the dispatch abstraction that API endpoints inject. It has **zero dependency on MediatR**.
- **`MediatRCommandBus`** (in `Infrastructure/Messaging/`) implements `ICommandBus` using MediatR's `ISender` internally.
- **Wrapper types** (`CommandRequest<TCommand, TResult>`, `VoidCommandRequest<TCommand>`) in `Infrastructure/Messaging/` bridge our interfaces to MediatR's `IRequest`/`IRequestHandler`.
- **Adapter handlers** (`CommandRequestHandler<TCommand, TResult>`, `VoidCommandRequestHandler<TCommand>`) in `Infrastructure/Messaging/` delegate from MediatR to our `ICommandHandler` implementations.

**If you see `using MediatR` in a file under Domain or Application — you are violating the rules. Stop and fix it.**

---

## Dispatch Architecture

```
API Endpoint
  │ injects ICommandBus (SharedKernel abstraction)
  │
  ▼ commandBus.EnvoyerAsync<TCommand, TResult>(commande, ct)
  │
MediatRCommandBus (Infrastructure)
  │ wraps into CommandRequest<TCommand, TResult> : IRequest<TResult>
  │ sends via ISender.Send (MediatR)
  │
CommandRequestHandler<TCommand, TResult> (Infrastructure)
  │ unwraps, delegates to ICommandHandler<TCommand, TResult>
  │
InscrireUtilisateur.Handler (Application)
  │ executes business orchestration
```

---

## Handler Registration — Automatic Assembly Scanning

Handlers are **never registered manually** in Program.cs. Instead, the Infrastructure provides an extension method `AddMessaging(Assembly applicationAssembly)` that:

1. Calls `AddMediatR(cfg => ...)` — registers ISender, IMediator
2. Scans the Application assembly for all `ICommandHandler<,>` and `ICommandHandler<>` implementations
3. Registers each handler in DI
4. Registers the corresponding MediatR adapter handler
5. Registers `ICommandBus` -> `MediatRCommandBus`

```csharp
// In Program.cs — one line per BC
builder.Services.AddMessaging(typeof(SomeCommandInBC).Assembly);
```

---

## API Endpoints Use ICommandBus — NEVER Inject Handlers Directly

```csharp
// ✅ CORRECT — endpoint injects ICommandBus
app.MapPost("/api/identite/inscription", async (InscriptionRequest request, ICommandBus commandBus, CancellationToken ct) =>
{
    var commande = new InscrireUtilisateur(request.Email, request.MotDePasse);
    var id = await commandBus.EnvoyerAsync<InscrireUtilisateur, UtilisateurId>(commande, ct);
    return Results.Created($"/api/identite/utilisateurs/{id.Valeur}", new { Id = id.Valeur });
});

// ❌ FORBIDDEN — direct handler injection
app.MapPost("/api/identite/inscription", async (InscriptionRequest request, InscrireUtilisateur.Handler handler, CancellationToken ct) =>
    ...
```

---

## DateTimeOffset + TimeProvider — No DateTime, No IHorloge

- Use `DateTimeOffset` everywhere, never `DateTime`.
- Use `TimeProvider` (built-in .NET 8+) for time abstraction, never a custom `IHorloge` port.
- Register in DI: `builder.Services.AddSingleton<TimeProvider>(TimeProvider.System);`
- In tests: use `FakeTimeProvider` from `Microsoft.Extensions.TimeProvider.Testing`.

---

## Ports Use Value Objects — Not Primitives

Application port signatures must use **domain Value Objects**, not raw primitives. See rule `port-repository.md`.

---

## Reconstitution — `Reconstituer()` Everywhere

The persistence reconstitution method is named `Reconstituer()` on ALL types: entities, value objects, typed Ids.

---

## AggregateRoot<TId> Base Class

All aggregate roots inherit from `AggregateRoot<TId>`. See rule `aggregate.md`.
