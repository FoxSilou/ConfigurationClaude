---
name: scaffold-architecture
description: >
  Use when scaffolding backend infrastructure, wiring vertical slices,
  or setting up CQRS read/write stacks, MediatR adapters, API endpoints,
  Event Sourcing infrastructure (IStateRebuilder, EventSerializer),
  or authentication/Identity (JWT, roles, hybrid Identity pattern).
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
│   │   └── Shared.Write.Infrastructure.csproj      ← MediatR command adapters, ES infra
│   └── Read/
│       └── Shared.Read.Infrastructure.csproj       ← MediatR query adapters
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
├── <BC>.UnitTests/
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
- **`IQuery<T>`**, **`IQueryHandler<TQuery, TResult>`**, **`IQueryBus`** are also defined in `Shared.Write.Domain/Abstractions/`. Zero MediatR dependency.
- **`ICommandBus`** is defined in `Shared.Write.Domain/Abstractions/`. This is the dispatch abstraction that API endpoints inject.
- **Command adapters** live in **`Shared.Write.Infrastructure/Messaging/`**: `MediatRCommandBus`, `CommandRequest`, `CommandRequestHandler`, `VoidCommandRequestHandler`, `AddWriteMessaging()`.
- **Query adapters** live in **`Shared.Read.Infrastructure/Messaging/`**: `MediatRQueryBus`, `QueryRequest`, `QueryRequestHandler`, `AddReadMessaging()`.
- This split respects strict CQRS: Write infrastructure handles Commands, Read infrastructure handles Queries.

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

Handlers are **never registered manually** in Program.cs. Two extension methods handle registration:

**`AddWriteMessaging(Assembly)`** (from `Shared.Write.Infrastructure`):
1. Calls `AddMediatR(cfg => ...)` — registers ISender, IMediator
2. Scans the Application assembly for all `ICommandHandler<,>` and `ICommandHandler<>` implementations
3. Registers each handler in DI
4. Registers the corresponding MediatR command adapter handler
5. Registers `ICommandBus` → `MediatRCommandBus`

**`AddReadMessaging(Assembly)`** (from `Shared.Read.Infrastructure`):
1. Scans the Read Application assembly for all `IQueryHandler<,>` implementations
2. Registers each handler in DI
3. Registers the corresponding MediatR query adapter handler
4. Registers `IQueryBus` → `MediatRQueryBus`

```csharp
// In Program.cs — one line per BC per stack
builder.Services.AddWriteMessaging(typeof(SomeCommandInBC).Assembly);
builder.Services.AddReadMessaging(typeof(SomeQueryInBC).Assembly);
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
  > `FakeTimeProvider` est dans le namespace `Microsoft.Extensions.Time.Testing` (le namespace diffère du nom du package NuGet `Microsoft.Extensions.TimeProvider.Testing`).

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

- **Shared.Write.Domain**: `IEventStore`, `IDomainEventHandler<T>`, `IDomainEventBus`, `Snapshot`, `ITypedId<T>`, `ICommand`, `ICommandBus`, `IQuery`, `IQueryBus`
- **Shared.Write.Infrastructure**: `MediatRCommandBus`, `MediatRDomainEventBus`, `AddWriteMessaging()`, `AddDomainEventHandlers()`, `SqlEventStore` (implements `IEventStore` + `IStoredEventReader`), `WriteDbContext` (shared across all BCs), `StoredEvent`, `AggregateSnapshot`, `AddEventSourcing()`, `IStateRebuilder<TAggregate, TId>`, `EventSerializer`, `IStoredEventPayload`, `IStoredEventReader`, `IEventPayloadMapper`, `ConcurrencyException`
- **Shared.Read.Infrastructure**: `MediatRQueryBus`, `AddReadMessaging()`, `ReadDbContext` (shared across all BCs, single DB `<SolutionName>_Read`), `AddReadDbContext()`
- **Per-BC Write Infrastructure**: `<Aggregate>StateRebuilder`, `EventSourced<Aggregate>Repository`
- **Per-BC Read Infrastructure**: projections (`<Event>Projection` implementing `IDomainEventHandler<TEvent>`), read models, `IEntityTypeConfiguration<T>` (registered in shared `ReadDbContext`)

---

## Authentication & Identity (Hybrid Pattern)

When a BC involves user authentication, follow the hybrid pattern described in rule `identity-framework.md`:

- **Domain is source of truth** — `Utilisateur` aggregate (event-sourced) owns roles, password hash, status
- **Identity is infrastructure** — `ApplicationUser`, `AppIdentityDbContext`, `AspNet*` tables live in the Read DB
- **Projections sync domain → Identity** — `IDomainEventHandler<T>` implementations write to Identity via `UserManager`
- **Ports**: `IPasswordHasher` (hash/verify), `ITokenGenerator` (JWT generation), `IUtilisateurAuthReader` (read auth data from Identity)
- **Login**: `SeConnecter` command reads from Identity (via ports), verifies password, generates JWT
- **JWT**: configured in `Api/Program.cs` with `AddAuthentication().AddJwtBearer()`, config in `appsettings.json`
- **`UserManager` is read-only** in infrastructure — domain events are the only write path
- **Sécurité basique** (see rule `identity-framework.md` § Sécurité basique):
  - Password policy: invariants in `MotDePasse` VO + synchronized Identity `Password` options
  - Lockout: activate Identity `Lockout` options + create `ILoginAttemptTracker` port + `IdentityLoginAttemptTracker` adapter
  - Rate limiting: `AddRateLimiter()` with `"auth"` policy on login/registration endpoints
  - Generic error messages on login failures (never reveal which field is wrong)
