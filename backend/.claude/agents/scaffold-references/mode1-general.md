# MODE 1 — GENERAL SCAFFOLDING

Use this mode when no bounded context name is provided.

## Workflow — General

```
PHASE 0 — DIAGNOSTIC
  ↓ (user gate)
PHASE 1 — SHARED WRITE DOMAIN
  ↓ (user gate)
PHASE 2 — SHARED WRITE INFRASTRUCTURE (command messaging + ES infra)
  ↓ (user gate)
PHASE 2b — SHARED READ INFRASTRUCTURE (query messaging)
  ↓ (user gate)
PHASE 3 — API SHELL (composition root, error middleware, health)
  ↓ (user gate)
PHASE 4 — E2E TEST HARNESS
  ↓ (user gate)
SMOKE TEST — everything compiles, tests pass
  ↓
GENERAL SCAFFOLD COMPLETE ✅
```

---

## GENERAL — PHASE 0 — DIAGNOSTIC

### Goal

Inventory what exists and what is missing in the shared foundation.

### Steps

1. Read the current solution structure (all `.csproj` files, `.sln`, folder structure).
2. Check for each shared concern:

| Concern | What to check | Expected location |
|---|---|---|
| **Solution file** | Does `<SolutionName>.sln` exist? | `backend/` |
| **Shared.Write.Domain project** | Does `Shared.Write.Domain.csproj` exist? | `src/Shared/Write/` |
| **AggregateRoot<TId>** | Base class + IAggregateRoot + IDomainEvent | `src/Shared/Write/` (in Shared.Write.Domain) |
| **ITypedId<T>** | Typed Id contract for serialization | `src/Shared/Write/` (in Shared.Write.Domain) |
| **CQRS abstractions** | ICommand, ICommandHandler, ICommandBus, IQuery, IQueryHandler, IQueryBus | `src/Shared/Write/Abstractions/` |
| **ES abstractions** | IEventStore, IDomainEventHandler<T>, IDomainEventBus, Snapshot | `src/Shared/Write/Abstractions/` |
| **Shared exceptions** | DomainException, NotFoundException | `src/Shared/Write/Exceptions/` |
| **Shared.Write.Infrastructure project** | Does `Shared.Write.Infrastructure.csproj` exist? | `src/Shared/Write/` |
| **Command messaging infrastructure** | MediatRCommandBus, command wrappers, adapters, AddWriteMessaging() | `src/Shared/Write/Messaging/` (in Shared.Write.Infrastructure) |
| **ES infrastructure** | IStateRebuilder, EventSerializer, TypedIdConverterFactory, ConcurrencyException | `src/Shared/Write/` (in Shared.Write.Infrastructure) |
| **Shared.Read.Infrastructure project** | Does `Shared.Read.Infrastructure.csproj` exist? | `src/Shared/Read/` |
| **Query messaging infrastructure** | MediatRQueryBus, query wrappers, adapters, AddReadMessaging() | `src/Shared/Read/Messaging/` (in Shared.Read.Infrastructure) |
| **API project** | Does the Api `.csproj` exist? | `src/Api/` |
| **Program.cs** | Composition root with minimal setup | `src/Api/Program.cs` |
| **Error middleware** | Global exception handler (Problem Details RFC 7807) | `src/Api/` |
| **Health endpoint** | `/health` endpoint | `src/Api/Program.cs` |
| **E2E test project** | Test project with WebApplicationFactory | `tests/` |
| **E2E smoke test** | Basic health check test | `tests/` |

3. Produce the diagnostic document.

### Diagnostic Document

Save to: `docs/scaffold-general-<date>.md`

```markdown
# Scaffold Diagnostic: General Foundation

## Solution Structure
- Solution file (<SolutionName>.sln): ✅ / ❌
- Shared.Write.Domain project: ✅ / ❌
- Shared.Write.Infrastructure project: ✅ / ❌
- Shared.Read.Infrastructure project: ✅ / ❌
- Api project: ✅ / ❌
- E2E test project: ✅ / ❌

## Shared.Write.Domain Status

| Concern | Status | Details |
|---|---|---|
| AggregateRoot<TId> + IAggregateRoot | ✅ / ❌ | |
| IDomainEvent | ✅ / ❌ | |
| ITypedId<T> | ✅ / ❌ | |
| ICommand / ICommandHandler | ✅ / ❌ | |
| ICommandBus | ✅ / ❌ | |
| IQuery / IQueryHandler | ✅ / ❌ | |
| IQueryBus | ✅ / ❌ | |
| IEventStore + Snapshot | ✅ / ❌ | |
| IDomainEventHandler<T> | ✅ / ❌ | |
| IDomainEventBus | ✅ / ❌ | |
| DomainException | ✅ / ❌ | |
| NotFoundException | ✅ / ❌ | |

## Shared.Write.Infrastructure Status

| Concern | Status | Details |
|---|---|---|
| MediatRCommandBus | ✅ / ❌ | |
| CommandRequest wrappers | ✅ / ❌ | |
| CommandRequestHandler adapters | ✅ / ❌ | |
| AddWriteMessaging() extension | ✅ / ❌ | |
| IStateRebuilder<TAggregate, TId> | ✅ / ❌ | |
| EventSerializer | ✅ / ❌ | |
| TypedIdConverterFactory | ✅ / ❌ | |
| ConcurrencyException | ✅ / ❌ | |

## Shared.Read.Infrastructure Status

| Concern | Status | Details |
|---|---|---|
| MediatRQueryBus | ✅ / ❌ | |
| QueryRequest wrappers | ✅ / ❌ | |
| QueryRequestHandler adapters | ✅ / ❌ | |
| AddReadMessaging() extension | ✅ / ❌ | |

## API Shell Status

| Concern | Status | Details |
|---|---|---|
| Program.cs | ✅ / ❌ | |
| Error middleware (Problem Details) | ✅ / ❌ | |
| Health endpoint | ✅ / ❌ | |
| TimeProvider registration | ✅ / ❌ | |

## E2E Test Harness Status

| Concern | Status | Details |
|---|---|---|
| Test project | ✅ / ❌ | |
| WebApplicationFactory setup | ✅ / ❌ | |
| Collection fixture | ✅ / ❌ | |
| Smoke test | ✅ / ❌ | |

## Work Plan
1. <what to create — phase 1>
2. <what to create — phase 2>
3. <what to create — phase 3>
4. <what to create — phase 4>
```

### Gate — End of PHASE 0

⛔ **GATE: Stop after producing the diagnostic document.**

Present a summary to the user:
- Document saved at `docs/scaffold-general-<date>.md`
- What exists vs what is missing
- Proposed work plan

Ask:
> *"Diagnostic terminé. Voici ce qui manque : [résumé]. Le plan de travail vous convient-il ? Confirmez pour commencer, ou ajustez."*

Wait for explicit user confirmation before proceeding to PHASE 1.

---

## GENERAL — PHASE 1 — SHARED WRITE DOMAIN

### Goal

Create the Shared.Write.Domain project with all shared abstractions (domain base types, CQRS, ES, exceptions).

### Steps

1. Create `src/Shared/Write/Shared.Write.Domain.csproj` (class library, **zero external NuGet dependencies**)
2. Create all types defined in rule `shared-kernel.md`, following its exact directory structure:
   - Domain base types: `IDomainEvent.cs`, `IAggregateRoot.cs`, `AggregateRoot.cs`, `ITypedId.cs`
   - CQRS abstractions in `Abstractions/`: `ICommand.cs`, `ICommandBus.cs`, `IQuery.cs`, `IQueryBus.cs`
   - ES abstractions in `Abstractions/`: `IEventStore.cs`, `IDomainEventHandler.cs`, `IDomainEventBus.cs`
   - Exceptions in `Exceptions/`: `DomainException.cs`, `NotFoundException.cs`

Use the exact type signatures from rule `shared-kernel.md`.

### Verification

Run `dotnet build` — must compile.

### Gate — End of PHASE 1

⛔ **GATE: Stop after creating Shared.Write.Domain.**

Present files created and build status. Ask:
> *"Shared.Write.Domain créé avec toutes les abstractions (CQRS + ES). Tout compile. Confirmez pour passer à Shared.Write.Infrastructure."*

---

## GENERAL — PHASE 2 — SHARED WRITE INFRASTRUCTURE

### Goal

Create Shared.Write.Infrastructure with command messaging (MediatR) and Event Sourcing infrastructure.

### Steps

1. Create `src/Shared/Write/Shared.Write.Infrastructure.csproj`
   - Reference Shared.Write.Domain
   - NuGet: `MediatR`, `Microsoft.Extensions.DependencyInjection.Abstractions`, `System.Text.Json`
2. Create MediatR **command** adapters in `Messaging/` — follow the adapter pattern from rule `mediatr.md`:
   - `CommandRequest.cs`, `CommandRequestHandler.cs`, `VoidCommandRequestHandler.cs`
   - `MediatRCommandBus.cs` — implements `ICommandBus`
   - `ServiceCollectionExtensions.cs` — `AddWriteMessaging(Assembly)`
   
   ⚠️ **CRITICAL: `AddWriteMessaging()` must register closed MediatR adapter types.**
   For each discovered `ICommandHandler<TCommand, TResult>`, register the corresponding `IRequestHandler<CommandRequest<TCommand, TResult>, TResult>`. Same for void handlers.
   Without this, MediatR's `ISender.Send()` cannot resolve the adapter and dispatch silently fails — `RegisterServicesFromAssembly` cannot discover open generic adapters in a different assembly.

3. Create ES infrastructure:
   - `EventStore/IStateRebuilder.cs`, `Serialization/EventSerializer.cs`, `Serialization/TypedIdConverter.cs`, `Serialization/TypedIdConverterFactory.cs`, `Serialization/ValueObjectConverterFactory.cs`, `Exceptions/ConcurrencyException.cs`

   ⚠️ **CRITICAL: `EventSerializer` must use `type.Name` (not `type.FullName`) as the type map key** — the `SqlEventStore` stores `GetType().Name`.

   ⚠️ **CRITICAL: `EventSerializer` default `JsonSerializerOptions` must include `TypedIdConverterFactory` and `ValueObjectConverterFactory`** — without these, serialization of Value Objects and Typed Ids in events fails.

### Verification

Run `dotnet build` — must compile.

### Gate — End of PHASE 2

⛔ **GATE: Stop after creating Shared.Write.Infrastructure.**

Present files created and build status. Ask:
> *"Shared.Write.Infrastructure créé (command messaging MediatR + infrastructure ES). Tout compile. Confirmez pour passer à Shared.Read.Infrastructure."*

---

## GENERAL — PHASE 2b — SHARED READ INFRASTRUCTURE

### Goal

Create Shared.Read.Infrastructure with query messaging (MediatR).

### Steps

1. Create `src/Shared/Read/Shared.Read.Infrastructure.csproj`
   - Reference Shared.Write.Domain
   - NuGet: `MediatR`, `Microsoft.Extensions.DependencyInjection.Abstractions`
2. Create MediatR **query** adapters in `Messaging/` — same adapter pattern as Write side (rule `mediatr.md`):
   - `QueryRequest.cs`, `QueryRequestHandler.cs`, `MediatRQueryBus.cs`, `ServiceCollectionExtensions.cs`
   
   ⚠️ **CRITICAL: `AddReadMessaging()` must register closed MediatR adapter types** — same pattern as `AddWriteMessaging()`. Without this, query dispatch fails.

### Verification

Run `dotnet build` — must compile.

### Gate — End of PHASE 2b

⛔ **GATE: Stop after creating Shared.Read.Infrastructure.**

Present files created and build status. Ask:
> *"Shared.Read.Infrastructure créé (query messaging MediatR). Tout compile. Confirmez pour passer au shell API."*

---

## GENERAL — PHASE 3 — API SHELL

### Goal

Create the API project with composition root, error middleware, and health endpoint.

### Steps

1. Create `src/Api/Api.csproj` (ASP.NET Core Web API)
   - Reference Shared.Write.Domain, Shared.Write.Infrastructure, Shared.Read.Infrastructure
2. Create `src/Api/Program.cs`:
   - Minimal composition root, `TimeProvider.System` singleton, health endpoint (`/health`)
   - `public partial class Program;` at end for E2E test access
3. Create error middleware — follow rule `error-handling.md` for exception-to-HTTP mapping and Problem Details (RFC 7807)

### Verification

Run `dotnet build` — must compile.

### Gate — End of PHASE 3

⛔ **GATE: Stop after creating API shell.**

Present files created and build status. Ask:
> *"Shell API créé avec Program.cs, error middleware et health endpoint. Tout compile. Confirmez pour créer le harness E2E."*

---

## GENERAL — PHASE 4 — E2E TEST HARNESS

### Goal

Create the E2E test project with WebApplicationFactory and a smoke test.

### Steps

1. Create `tests/<SolutionName>.E2E.Tests/<SolutionName>.E2E.Tests.csproj`
   - Reference the Api project
   - Add NuGet packages: `Microsoft.AspNetCore.Mvc.Testing`, `FluentAssertions`, `Microsoft.Extensions.TimeProvider.Testing`, `xunit`
   - Add the project to the solution
2. Create `E2EFixture.cs`:
   - Extends `WebApplicationFactory<Program>`
   - Replaces `TimeProvider` with `FakeTimeProvider`
   - Implements `IAsyncLifetime` for lifecycle
3. Create `E2ECollection.cs`:
   - `[CollectionDefinition("E2E")]`
4. Create smoke test following E2E conventions from skill `e2e-testing`:
   - Test name: `Api_doit_demarrer_sans_erreur`
   - GET /health → 200

### Verification

Run `dotnet test` — smoke test must pass.

### Gate — End of PHASE 4

⛔ **GATE: Stop after the smoke test passes.**

Present:
- E2E test project created
- Test infrastructure files (list with paths)
- Smoke test status ✅
- All tests status ✅

Ask:
> *"Harness E2E en place. Le smoke test passe. Le scaffolding général est terminé. Vous pouvez maintenant lancer `/scaffold-back <BoundedContext>` pour câbler un bounded context spécifique."*

---

## General Scaffold — Final Report

```
General Scaffold complete ✅

Shared.Write.Domain:
- AggregateRoot<TId>, IAggregateRoot, IDomainEvent, ITypedId<T>
- ICommand<T>, ICommandHandler<,>, ICommandBus
- IQuery<T>, IQueryHandler<,>, IQueryBus
- IEventStore, IDomainEventHandler<T>, IDomainEventBus, Snapshot
- DomainException, NotFoundException

Shared.Write.Infrastructure:
- ICommandBus → MediatRCommandBus (MediatR hidden in Infrastructure)
- AddWriteMessaging() auto-scans command handlers + registers closed MediatR adapters
- IStateRebuilder<TAggregate, TId>
- EventSerializer (type.Name key, with TypedIdConverterFactory + ValueObjectConverterFactory)
- TypedIdConverterFactory, ValueObjectConverterFactory
- ConcurrencyException

Shared.Read.Infrastructure:
- IQueryBus → MediatRQueryBus (MediatR hidden in Infrastructure)
- AddReadMessaging() auto-scans query handlers + registers closed MediatR adapters
- MediatR NEVER referenced in Domain or Application ✅

API shell:
- Program.cs with TimeProvider, health endpoint, error middleware
- Problem Details (RFC 7807) for domain exceptions + ConcurrencyException

E2E test harness:
- Project: tests/<SolutionName>.E2E.Tests/
- WebApplicationFactory with FakeTimeProvider
- Smoke test: green ✅
```
