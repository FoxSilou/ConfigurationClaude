---
name: scaffold-architecture
description: >
  Backend infrastructure architecture rules for scaffolding.
  Covers: CQRS read/write stack separation, MediatR as infrastructure adapter,
  dispatch architecture (ICommandBus -> MediatRCommandBus -> Handler),
  automatic handler registration via AddMessaging(), API endpoint conventions,
  DateTimeOffset + TimeProvider, ports with Value Objects, Reconstituer() pattern,
  AggregateRoot<TId> base class, Event Sourcing infrastructure (IStateRebuilder, EventSerializer).
  Use when scaffolding backend infrastructure or wiring vertical slices.
user-invocable: false
---

# Skill: Scaffold Architecture — Backend Infrastructure Rules

These rules are NON-NEGOTIABLE when writing backend infrastructure code.

---

## Solution & Project Structure

The solution name is defined in `CLAUDE.md`. Projects are organized under `src/` with a `Shared/` folder for cross-cutting concerns and one folder per Bounded Context.

**Critical**: projects (`.csproj` files) are placed **directly** under `Write/` or `Read/` — there are NO intermediate `Domain/`, `Application/`, or `Infrastructure/` subdirectories.

```
<SolutionName>.sln
src/
├── Shared/
│   ├── Write/
│   │   ├── Shared.Write.Domain.csproj              ← Pure C#, zero deps
│   │   └── Shared.Write.Infrastructure.csproj      ← MediatR, ES infra
│   └── Read/                                        ← Created when needed
├── <BoundedContext>/
│   ├── Write/
│   │   ├── <BC>.Write.Domain.csproj
│   │   ├── <BC>.Write.Application.csproj
│   │   └── <BC>.Write.Infrastructure.csproj
│   └── Read/
│       ├── <BC>.Read.Application.csproj
│       └── <BC>.Read.Infrastructure.csproj
├── Api/
│   └── Api.csproj
tests/
├── <BC>.Write.Application.UnitTests/
└── <SolutionName>.E2E.Tests/
```

---

## CQRS — Separate Read / Write Stacks

The project follows **strict CQRS**. Each bounded context has separate Read and Write stacks across all layers. See rule `cqrs.md`.

When scaffolding a BC, create BOTH stacks (even if Read side is empty initially).

---

## MediatR Is an Infrastructure Detail — NEVER in Domain or Application

MediatR lives **exclusively** in Infrastructure. See rule `mediatr.md`.

- **`ICommand<T>`**, **`ICommandHandler<TCommand, TResult>`**, **`ICommand`**, **`ICommandHandler<TCommand>`** are generic interfaces defined in `Shared.Write.Domain/Abstractions/`. They have **zero dependency on MediatR**.
- **`ICommandBus`** is defined in `Shared.Write.Domain/Abstractions/`. This is the dispatch abstraction that API endpoints inject. It has **zero dependency on MediatR**.
- **`MediatRCommandBus`** (in `Shared.Write.Infrastructure/Messaging/`) implements `ICommandBus` using MediatR's `ISender` internally.
- **Wrapper types** (`CommandRequest<TCommand, TResult>`, `VoidCommandRequest<TCommand>`) in `Shared.Write.Infrastructure/Messaging/` bridge our interfaces to MediatR's `IRequest`/`IRequestHandler`.
- **Adapter handlers** (`CommandRequestHandler<TCommand, TResult>`, `VoidCommandRequestHandler<TCommand>`) in `Shared.Write.Infrastructure/Messaging/` delegate from MediatR to our `ICommandHandler` implementations.

**If you see `using MediatR` in a file under Domain or Application — you are violating the rules. Stop and fix it.**

---

## Dispatch Architecture

```
API Endpoint
  │ injects ICommandBus (Shared.Write.Domain abstraction)
  │
  ▼ commandBus.EnvoyerAsync<TCommand, TResult>(commande, ct)
  │
MediatRCommandBus (Shared.Write.Infrastructure)
  │ wraps into CommandRequest<TCommand, TResult> : IRequest<TResult>
  │ sends via ISender.Send (MediatR)
  │
CommandRequestHandler<TCommand, TResult> (Shared.Write.Infrastructure)
  │ unwraps, delegates to ICommandHandler<TCommand, TResult>
  │
InscrireUtilisateur.Handler (Application)
  │ executes business orchestration
```

---

## Handler Registration — Automatic Assembly Scanning

Handlers are **never registered manually** in Program.cs. Instead, Shared.Write.Infrastructure provides an extension method `AddMessaging(Assembly applicationAssembly)` that:

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

---

## Event Sourcing Infrastructure

The shared ES infrastructure lives in `Shared.Write.Infrastructure` and `Shared.Write.Domain`. See skill `event-sourcing` for full details.

- **Shared.Write.Domain**: `IEventStore`, `IProjection`, `Snapshot`, `ITypedId<T>`
- **Shared.Write.Infrastructure**: `IStateRebuilder<TAggregate, TId>`, `EventSerializer`, `TypedIdConverterFactory`, `ConcurrencyException`
- **Per-BC Infrastructure**: `EventStoreDbContext`, `StoredEvent`, `AggregateSnapshot`, `<Aggregate>StateRebuilder`, `EventSourced<Aggregate>Repository`, projections
