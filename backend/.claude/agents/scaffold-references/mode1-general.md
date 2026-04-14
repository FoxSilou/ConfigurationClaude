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
| **ES infrastructure** | SqlEventStore, WriteDbContext, StoredEvent, AggregateSnapshot, AddEventSourcing(), IStateRebuilder, EventSerializer, IStoredEventPayload, IStoredEventReader, IEventPayloadMapper, ConcurrencyException | `src/Shared/Write/` (in Shared.Write.Infrastructure) |
| **Shared.Read.Infrastructure project** | Does `Shared.Read.Infrastructure.csproj` exist? | `src/Shared/Read/` |
| **Query messaging infrastructure** | MediatRQueryBus, query wrappers, adapters, AddReadMessaging() | `src/Shared/Read/Messaging/` (in Shared.Read.Infrastructure) |
| **API project** | Does the Api `.csproj` exist? | `src/Api/` |
| **Program.cs** | Composition root with minimal setup | `src/Api/Program.cs` |
| **Error middleware** | Global exception handler (Problem Details RFC 7807) | `src/Api/` |
| **Health endpoint** | `/health` endpoint | `src/Api/Program.cs` |
| **OpenAPI** | `AddOpenApi()` + `MapOpenApi()` + `Microsoft.Extensions.ApiDescription.Server` in csproj | `src/Api/` |
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
| SqlEventStore | ✅ / ❌ | |
| WriteDbContext | ✅ / ❌ | |
| StoredEvent + AggregateSnapshot models | ✅ / ❌ | |
| AddEventSourcing() extension | ✅ / ❌ | |
| IStateRebuilder<TAggregate, TId> | ✅ / ❌ | |
| EventSerializer (assembly scanning, discriminator, snapshot) | ✅ / ❌ | |
| IStoredEventPayload (marker interface) | ✅ / ❌ | |
| IStoredEventReader | ✅ / ❌ | |
| IEventPayloadMapper | ✅ / ❌ | |
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
| OpenAPI (AddOpenApi + MapOpenApi) | ✅ / ❌ | |
| OpenAPI spec generation (ApiDescription.Server) | ✅ / ❌ | |

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
   - NuGet: `MediatR`, `Microsoft.EntityFrameworkCore`, `Microsoft.EntityFrameworkCore.SqlServer`, `Microsoft.Extensions.DependencyInjection.Abstractions`, `System.Text.Json`
2. Create MediatR **command** adapters in `Messaging/` — follow the adapter pattern from rule `mediatr.md`:
   - `CommandRequest.cs`, `CommandRequestHandler.cs`, `VoidCommandRequestHandler.cs`
   - `MediatRCommandBus.cs` — implements `ICommandBus`
   - `ServiceCollectionExtensions.cs` — `AddWriteMessaging(Assembly)`
   
   ⚠️ **CRITICAL: `AddWriteMessaging()` must register closed MediatR adapter types.**
   For each discovered `ICommandHandler<TCommand, TResult>`, register the corresponding `IRequestHandler<CommandRequest<TCommand, TResult>, TResult>`. Same for void handlers.
   Without this, MediatR's `ISender.Send()` cannot resolve the adapter and dispatch silently fails — `RegisterServicesFromAssembly` cannot discover open generic adapters in a different assembly.

3. Create ES infrastructure:
   - `Serialization/EventSerializer.cs` — serializes `IStoredEventPayload` records (primitives only, no custom JSON converters)
   - `EventStore/Models/StoredEvent.cs`, `EventStore/Models/AggregateSnapshot.cs` — EF Core persistence models for the event store
   - `EventStore/WriteDbContext.cs` — shared DbContext with `DbSet<StoredEvent>`, `DbSet<AggregateSnapshot>`, unique constraint on `(EntityName, EntityId, StreamVersion)`
   - `EventStore/SqlEventStore.cs` — implements `IEventStore` and `IStoredEventReader` using `WriteDbContext` + `EventSerializer` + `IEventPayloadMapper`
   - `EventStore/InMemoryEventStore.cs` — in-memory implementation for unit tests
   - `EventStore/ServiceCollectionExtensions.cs` — `AddEventSourcing(string connectionString, params Assembly[] payloadAssemblies)` registers `WriteDbContext`, `EventSerializer`, `SqlEventStore`, `IStoredEventReader`
   - `EventStore/IStateRebuilder.cs`
   - `EventStore/IStoredEventPayload.cs` — marker interface for payload records
   - `EventStore/IStoredEventReader.cs` — reads payloads from the store
   - `EventStore/IEventPayloadMapper.cs` — maps `IDomainEvent` → `IStoredEventPayload`
   - `Exceptions/ConcurrencyException.cs`

   ⚠️ **CRITICAL: `EventSerializer` must use `type.Name` (not `type.FullName`) as the type map key** — the `SqlEventStore` stores `GetType().Name`.

   ⚠️ **CRITICAL: `EventSerializer` constructor takes `params Assembly[]`** — scans for `IStoredEventPayload` implementations and builds a discriminator → CLR type map. Must include `GetDiscriminator()`, `Serialize()`, `Deserialize(discriminator, json)`, `SerializeSnapshot()`, `DeserializeSnapshot()`.

   ⚠️ **CRITICAL: `EventSerializer` uses plain `JsonSerializerOptions` with no custom converters** — payloads contain only primitives (`Guid`, `string`, `DateTimeOffset`), so standard System.Text.Json handles everything.

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
   - NuGet: `MediatR`, `Microsoft.EntityFrameworkCore`, `Microsoft.EntityFrameworkCore.SqlServer`, `Microsoft.Extensions.DependencyInjection.Abstractions`
2. Create MediatR **query** adapters in `Messaging/` — same adapter pattern as Write side (rule `mediatr.md`):
   - `QueryRequest.cs`, `QueryRequestHandler.cs`, `MediatRQueryBus.cs`, `ServiceCollectionExtensions.cs`
   
   ⚠️ **CRITICAL: `AddReadMessaging()` must register closed MediatR adapter types** — same pattern as `AddWriteMessaging()`. Without this, query dispatch fails.

3. Create `ReadDbContext.cs` — **single shared ReadDbContext** for the entire solution:
   - `public sealed class ReadDbContext(DbContextOptions<ReadDbContext> options) : DbContext(options)`
   - No `DbSet<T>` properties — entities are discovered via `IEntityTypeConfiguration<T>` provided by each BC
   - `OnModelCreating` applies configurations from assemblies passed during DI registration
4. Create `ServiceCollectionExtensions.cs` — `AddReadDbContext(string connectionString, params Assembly[] readInfraAssemblies)`:
   - Registers `ReadDbContext` with `UseSqlServer(connectionString)`
   - Stores the assemblies so `OnModelCreating` can call `ApplyConfigurationsFromAssembly()` for each

### Verification

Run `dotnet build` — must compile.

### Gate — End of PHASE 2b

⛔ **GATE: Stop after creating Shared.Read.Infrastructure.**

Present files created and build status. Ask:
> *"Shared.Read.Infrastructure créé (query messaging MediatR + ReadDbContext partagé). Tout compile. Confirmez pour passer au shell API."*

---

## GENERAL — PHASE 3 — API SHELL

### Goal

Create the API project with composition root, error middleware, and health endpoint.

### Steps

1. Create `src/Api/Api.csproj` (ASP.NET Core Web API)
   - Reference Shared.Write.Domain, Shared.Write.Infrastructure, Shared.Read.Infrastructure
   - NuGet: `Microsoft.EntityFrameworkCore.Design` (PrivateAssets=all), `Microsoft.EntityFrameworkCore.SqlServer`
   - NuGet: `Microsoft.AspNetCore.OpenApi`
   - NuGet: `Microsoft.Extensions.ApiDescription.Server` (PrivateAssets=all) — generates `Api.json` OpenAPI spec at build time
   - Add MSBuild properties for OpenAPI spec generation:
     ```xml
     <OpenApiDocumentsDirectory>$(MSBuildThisFileDirectory)..\..\</OpenApiDocumentsDirectory>
     <OpenApiGenerateDocuments>true</OpenApiGenerateDocuments>
     ```
     This emits `Api.json` at the backend root directory on each build. The frontend NSwag client reads this file.
2. Create `src/Api/Program.cs`:
   - Minimal composition root, `TimeProvider.System` singleton, health endpoint (`/health`)
   - `builder.Services.AddOpenApi()` — registers OpenAPI document generation services
   - `app.MapOpenApi()` — exposes `/openapi/v1.json` at runtime
   - `public partial class Program;` at end for E2E test access
   - Register `AddEventSourcing(connectionString, domainAssemblies)` for the SQL event store
   - Register `AddReadDbContext(connectionString, readInfraAssemblies)` for the shared ReadDbContext
   - Connection strings read from `builder.Configuration.GetConnectionString("Write")` and `GetConnectionString("Read")`
3. Create `appsettings.Development.json` with connection strings:
   ```json
   {
     "ConnectionStrings": {
       "Write": "Server=localhost;Database=<SolutionName>_Write;Trusted_Connection=True;TrustServerCertificate=True",
       "Read": "Server=localhost;Database=<SolutionName>_Read;Trusted_Connection=True;TrustServerCertificate=True"
     }
   }
   ```
4. Pin dev ports — overwrite `src/Api/Properties/launchSettings.json` so `applicationUrl` is `"https://localhost:5001;http://localhost:5000"` (do NOT keep the random ports generated by `dotnet new`).
5. Configure CORS:
   - Add `builder.Services.AddCors(...)` reading allowed origins from `Configuration["Cors:Origins"]`
   - Add `app.UseCors()` **before** the error handling middleware
   - Add a `Cors:Origins` section in `appsettings.Development.json` with the pinned frontend dev URLs : `["https://localhost:5101", "http://localhost:5100"]`
   - In production `appsettings.json`, leave the section empty (`[]`) — origins must be explicitly configured per environment
   - **Contrat de ports dev partagé** : backend `5001/5000`, frontend `5101/5100`. Symétrique avec `frontend/.claude/agents/scaffold-front.md` (PHASE 1 launchSettings + `wwwroot/appsettings.json:ApiBaseUrl`). Ne pas changer un côté sans synchroniser l'autre — sinon `ERR_CONNECTION_REFUSED` ou rejet CORS.
4. Create error middleware — follow rule `error-handling.md` for exception-to-HTTP mapping and Problem Details (RFC 7807)

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
   - Add NuGet packages: `Microsoft.AspNetCore.Mvc.Testing`, `FluentAssertions`, `Microsoft.Extensions.TimeProvider.Testing`, `Testcontainers.MsSql`, `xunit`
   - Add the project to the solution
2. Create `E2EFixture.cs`:
   - Extends `WebApplicationFactory<Program>`
   - Uses `Testcontainers.MsSql` — starts a SQL Server container in `InitializeAsync()`
   - Replaces `WriteDbContext` and `ReadDbContext` with `UseSqlServer(_sqlContainer.GetConnectionString())`
   - Replaces `TimeProvider` with `FakeTimeProvider`
     > `FakeTimeProvider` : namespace `Microsoft.Extensions.Time.Testing` (NuGet : `Microsoft.Extensions.TimeProvider.Testing`)
   - Calls `EnsureCreated()` on `WriteDbContext` and `ReadDbContext` after container startup
   - Implements `IAsyncLifetime` for lifecycle (start container → stop container)
     > **⚠️ xUnit 2.9.x** : `IAsyncLifetime` retourne **`Task`**, PAS `ValueTask`. Ne pas utiliser `ValueTask` — erreur de compilation.
3. Create `E2ECollection.cs`:
   - `[CollectionDefinition("E2E")]` with `ICollectionFixture<E2EFixture>`
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
- SqlEventStore (implements IEventStore, SQL Server)
- WriteDbContext + StoredEvent + AggregateSnapshot (shared, single DB <SolutionName>_Write)
- AddEventSourcing(connectionString, assemblies) — one-line DI registration
- IStateRebuilder<TAggregate, TId>
- EventSerializer (assembly scanning, discriminator, type.Name key, snapshot support, no custom converters — payloads are primitives)
- IStoredEventPayload, IStoredEventReader, IEventPayloadMapper
- InMemoryEventStore (for unit tests)
- ConcurrencyException

Shared.Read.Infrastructure:
- IQueryBus → MediatRQueryBus (MediatR hidden in Infrastructure)
- AddReadMessaging() auto-scans query handlers + registers closed MediatR adapters
- ReadDbContext (shared, single DB <SolutionName>_Read, no DbSets — uses IEntityTypeConfiguration<T> from BC assemblies)
- AddReadDbContext(connectionString, assemblies) — one-line DI registration
- MediatR NEVER referenced in Domain or Application ✅

API shell:
- Program.cs with TimeProvider, AddEventSourcing(), AddReadDbContext(), health endpoint, CORS, error middleware
- Connection strings in appsettings.Development.json (Write + Read)
- Problem Details (RFC 7807) for domain exceptions + ConcurrencyException
- OpenAPI: AddOpenApi() + MapOpenApi() + Api.json generated at backend root via ApiDescription.Server

E2E test harness:
- Project: tests/<SolutionName>.E2E.Tests/
- WebApplicationFactory with Testcontainers SQL Server + FakeTimeProvider
- EnsureCreated() for WriteDbContext + ReadDbContext
- Smoke test: green ✅
```
