# MODE 3 — AGGREGATE SCAFFOLDING

Use this mode when both a bounded context name AND an aggregate name are provided.

**Prerequisite**: General scaffolding (Mode 1) and BC scaffolding (Mode 2) must be completed. The following must exist:
- Shared ES infrastructure: `WriteDbContext`, `SqlEventStore`, `AddEventSourcing()` in `Shared.Write.Infrastructure`
- All 5 BC projects (`<BC>.Write.Domain`, `<BC>.Write.Application`, `<BC>.Write.Infrastructure`, `<BC>.Read.Application`, `<BC>.Read.Infrastructure`)
- `<BC>EventPayloadMapper` in `<BC>.Write.Infrastructure/EventStore/`
- `ReadDbContext` (shared) in `Shared.Read.Infrastructure/`
- Write `ServiceCollectionExtensions` in `<BC>.Write.Infrastructure/`
- Read `ServiceCollectionExtensions` in `<BC>.Read.Infrastructure/`
- `InternalsVisibleTo` for Infrastructure in `<BC>.Write.Domain.csproj`

### What this mode produces

A **minimal aggregate with only an Id** — no business-specific properties or value objects. This is intentional: business logic comes later via `/task-implement-feature-back` using TDD. The scaffold provides the full plumbing so the aggregate is functional end-to-end (POST creates, GET retrieves).

## Workflow — Aggregate

```
PHASE 0 — DIAGNOSTIC
  ↓ (user gate)
PHASE 1 — WRITE DOMAIN (typed Id, event, aggregate, repository port)
  ↓ (user gate)
PHASE 2 — WRITE APPLICATION (creation command + handler)
  ↓ (user gate)
PHASE 3 — WRITE INFRASTRUCTURE (payload, mapper update, state rebuilder, ES repository)
  ↓ (user gate)
PHASE 4 — READ SIDE (read model, DbContext update, projection, query, read repository)
  ↓ (user gate)
PHASE 5 — WIRING (DI registration updates, API endpoints)
  ↓ (user gate)
SMOKE TEST — everything compiles, existing tests pass
  ↓
AGGREGATE SCAFFOLD COMPLETE ✅
```

---

## AGGREGATE — PHASE 0 — DIAGNOSTIC

### Goal

Verify prerequisites and inventory what already exists for this aggregate.

### Steps

1. **Verify BC prerequisites**: check that all 5 BC projects, WriteDbContext, SqlEventStore, `<BC>EventPayloadMapper`, `ReadDbContext (shared)`, both ServiceCollectionExtensions exist. If any is missing → stop and inform user to run BC scaffolding first.
2. **Check aggregate does not already exist**: look for `<Aggregate>.cs` in `<BC>.Write.Domain/Aggregates/`, `<Aggregate>Id.cs` in `ValueObjects/`. If the aggregate already exists → inform user and stop.
3. Produce the diagnostic document.

### Diagnostic Document

Save to: `docs/scaffold-<bc>-<aggregate>-<date>.md`

```markdown
# Scaffold Diagnostic: Aggregate <Aggregate> in <BoundedContext>

## Prerequisites
| Concern | Status |
|---|---|
| <BC>.Write.Domain project | ✅ / ❌ |
| <BC>.Write.Application project | ✅ / ❌ |
| <BC>.Write.Infrastructure project | ✅ / ❌ |
| <BC>.Read.Application project | ✅ / ❌ |
| <BC>.Read.Infrastructure project | ✅ / ❌ |
| WriteDbContext (shared) | ✅ / ❌ |
| SqlEventStore (shared) | ✅ / ❌ |
| <BC>EventPayloadMapper | ✅ / ❌ |
| ReadDbContext (shared) | ✅ / ❌ |
| Write ServiceCollectionExtensions | ✅ / ❌ |
| Read ServiceCollectionExtensions | ✅ / ❌ |
| InternalsVisibleTo | ✅ / ❌ |

## Aggregate Status
- <Aggregate>Id: ✅ exists / ❌ missing
- <Aggregate> aggregate: ✅ exists / ❌ missing
- <Aggregate>Cree event: ✅ exists / ❌ missing

## Work Plan
1. Write Domain — <Aggregate>Id, <Aggregate>Cree, <Aggregate>, I<Aggregate>Repository
2. Write Application — Creer<Aggregate> command + handler
3. Write Infrastructure — payload, mapper update, state rebuilder, ES repository
4. Read side — read model, projection, query, read repository
5. Wiring — DI + API endpoints
```

### Gate — End of PHASE 0

⛔ **GATE: Stop after producing the diagnostic document.**

Ask:
> *"Diagnostic terminé. Tous les prérequis BC sont en place. L'agrégat <Aggregate> n'existe pas encore. Le plan de travail vous convient-il ? Confirmez pour commencer."*

Wait for explicit user confirmation.

---

## AGGREGATE — PHASE 1 — WRITE DOMAIN

### Goal

Create the typed Id, creation event, aggregate class, and repository port for the new aggregate.

### Steps

1. **Create `<BC>.Write.Domain/ValueObjects/<Aggregate>Id.cs`** — Follow rule `value-object.md` for typed Id pattern:
   - `readonly record struct` implementing `ITypedId<Guid>`
   - `Nouveau()` and `Reconstituer(Guid)` factory methods
   - Property `Valeur`

2. **Create `<BC>.Write.Domain/Events/<Aggregate>Cree.cs`** — Follow rule `domain-event.md`:
   - `sealed record` implementing `IDomainEvent`
   - Properties: `<Aggregate>Id`, `DateTimeOffset OccurredOn`
   - Factory method `Creer(<Aggregate>Id id, DateTimeOffset maintenant)`

3. **Create `<BC>.Write.Domain/Aggregates/<Aggregate>.cs`** — Follow rules `aggregate.md` and `entity.md`:
   - Inherits `AggregateRoot<<Aggregate>Id>`
   - Private constructor with invariant validation
   - `Creer(<Aggregate>Id id, DateTimeOffset maintenant)` — raises `<Aggregate>Cree` event
   - `internal static Reconstituer(<Aggregate>Id id)` — no events
   - **Only Id property** — no business properties

4. **Create `<BC>.Write.Domain/Ports/I<Aggregate>Repository.cs`** — Follow rule `port-repository.md`:
   - `ObtenirParIdAsync(<Aggregate>Id id, CancellationToken ct)`
   - `AjouterAsync(<Aggregate> aggregate, CancellationToken ct)`

### Verification

Run `dotnet build` — must compile.

### Gate — End of PHASE 1

⛔ **GATE: Stop after creating Write Domain files.**

Present files created and build status. Ask:
> *"Write Domain créé : <Aggregate>Id, <Aggregate>Cree, <Aggregate>, I<Aggregate>Repository. Tout compile. Confirmez pour passer à Write Application."*

---

## AGGREGATE — PHASE 2 — WRITE APPLICATION

### Goal

Create the creation command with its nested handler.

### Steps

1. **Create `<BC>.Write.Application/Creer<Aggregate>.cs`** — Follow rule `command.md`:
   - `sealed record Creer<Aggregate> : ICommand<<Aggregate>Id>`
   - Nested `sealed class Handler` implementing `ICommandHandler<Creer<Aggregate>, <Aggregate>Id>`
   - Handler dependencies: `I<Aggregate>Repository`, `TimeProvider`
   - Handler logic: create Id via `Nouveau()`, get time via `timeProvider.GetUtcNow()`, call `<Aggregate>.Creer(id, maintenant)`, persist via `repository.AjouterAsync()`
   - ⚠️ **No `using MediatR`** — `ICommand<T>` and `ICommandHandler<,>` are our own interfaces from Shared.Write.Domain

### Verification

Run `dotnet build` — must compile.

### Gate — End of PHASE 2

⛔ **GATE: Stop after creating Write Application files.**

Present files created and build status. Ask:
> *"Write Application créé : Creer<Aggregate> command + handler. Tout compile. Confirmez pour passer à Write Infrastructure."*

---

## AGGREGATE — PHASE 3 — WRITE INFRASTRUCTURE

### Goal

Create the event payload, update the payload mapper, create the state rebuilder and event-sourced repository.

### Steps

1. **Create `<BC>.Write.Infrastructure/EventStore/Payloads/<Aggregate>CreePayload.cs`**:
   - `internal sealed record` implementing `IStoredEventPayload`
   - Properties: `Guid <Aggregate>Id`, `DateTimeOffset OccurredOn`

2. **Modify `<BC>.Write.Infrastructure/EventStore/<BC>EventPayloadMapper.cs`**:
   - Add a new case in the `ToPayload` switch expression mapping `<Aggregate>Cree` → `<Aggregate>CreePayload`
   - Extract `.Valeur` from typed Ids when mapping to payload

3. **Create `<BC>.Write.Infrastructure/EventStore/StateRebuilders/<Aggregate>StateRebuilder.cs`**:
   - Implements `IStateRebuilder<<Aggregate>, <Aggregate>Id>`
   - Folds `IStoredEventPayload` list, tracking aggregate state through switch cases
   - Calls `<Aggregate>.Reconstituer()` at the end — follow rule `event-sourcing.md`

4. **Create `<BC>.Write.Infrastructure/Persistence/EventSourced<Aggregate>Repository.cs`**:
   - Implements `I<Aggregate>Repository`
   - Dependencies: `IEventStore`, `IStoredEventReader`, `IStateRebuilder<<Aggregate>, <Aggregate>Id>`, `IDomainEventBus`
   - `ObtenirParIdAsync`: read payloads → rebuild via state rebuilder
   - `AjouterAsync`: append events to stream → publish via domain event bus

### Verification

Run `dotnet build` — must compile.
Run `dotnet test` — all existing tests must remain green.

### Gate — End of PHASE 3

⛔ **GATE: Stop after creating Write Infrastructure files.**

Present files created/modified and build status. Ask:
> *"Write Infrastructure créé : payload, mapper mis à jour, state rebuilder, repository ES. Tout compile et les tests passent. Confirmez pour passer au Read side."*

---

## AGGREGATE — PHASE 4 — READ SIDE

### Goal

Create the read model, update the ReadDbContext, create the projection, query, DTO, and read repository.

### Steps

1. **Create `<BC>.Read.Infrastructure/Models/<Aggregate>ReadModel.cs`**:
   - `internal sealed class` with EF Core data annotations (rule `efcore.md`)
   - `[Table("<FrenchPlural>")]` — e.g., `Parties`, `Utilisateurs`, `Tournois`
   - `[Key] public Guid Id { get; set; }`

2. **Create `<BC>.Read.Infrastructure/Configurations/<Aggregate>ReadModelConfiguration.cs`**:
   - Implements `IEntityTypeConfiguration<<Aggregate>ReadModel>`
   - Configures the entity in the shared `ReadDbContext` (from `Shared.Read.Infrastructure`)

3. **Create `<BC>.Read.Infrastructure/Projections/<Aggregate>CreeProjection.cs`**:
   - Implements `IDomainEventHandler<<Aggregate>Cree>`
   - Dependency: `ReadDbContext`
   - Inserts a new `<Aggregate>ReadModel` row, extracting `.Valeur` from typed Ids

4. **Create `<BC>.Read.Application/Ports/I<Aggregate>ReadRepository.cs`**:
   - `ObtenirParIdAsync(Guid id, CancellationToken ct)` returning `<Aggregate>Dto?`

5. **Create `<BC>.Read.Application/Obtenir<Aggregate>.cs`** — Follow rule `query.md`:
   - `sealed record <Aggregate>Dto(Guid Id)`
   - `sealed record Obtenir<Aggregate>(Guid <Aggregate>Id) : IQuery<<Aggregate>Dto?>`
   - Nested `Handler` using `I<Aggregate>ReadRepository`
   - ⚠️ **No `using MediatR`**

6. **Create `<BC>.Read.Infrastructure/EfCore<Aggregate>ReadRepository.cs`**:
   - Implements `I<Aggregate>ReadRepository`
   - Uses `ReadDbContext` with `AsNoTracking()`

### Verification

Run `dotnet build` — must compile.
Run `dotnet test` — all existing tests must remain green.

### Gate — End of PHASE 4

⛔ **GATE: Stop after creating Read side files.**

Present files created/modified and build status. Ask:
> *"Read side créé : read model, projection, query, repository. Tout compile et les tests passent. Confirmez pour passer au wiring."*

---

## AGGREGATE — PHASE 5 — WIRING

### Goal

Wire the new aggregate into the DI container and create API endpoints.

### Steps

1. **Modify Write `ServiceCollectionExtensions.cs`** (`<BC>.Write.Infrastructure/ServiceCollectionExtensions.cs`):
   - Add `services.AddScoped<I<Aggregate>Repository, EventSourced<Aggregate>Repository>()`
   - Add `services.AddScoped<IStateRebuilder<<Aggregate>, <Aggregate>Id>, <Aggregate>StateRebuilder>()`
   - **Pas d'appel `serializer.RegisterTypeAlias(...)`** : `EventSerializer` auto-découvre les payloads par `type.Name` via les assemblies passés à `AddEventSourcing(...)` (Mode 1 / Mode 2). Le payload est résolu automatiquement dès que le projet `<BC>.Write.Infrastructure` est référencé.

2. **Modify Read `ServiceCollectionExtensions.cs`** (`<BC>.Read.Infrastructure/ServiceCollectionExtensions.cs`):
   - Add `services.AddScoped<I<Aggregate>ReadRepository, EfCore<Aggregate>ReadRepository>()`

3. **Create or modify API endpoints** (with mandatory OpenAPI annotations):
   - **POST** `/api/<bc>/<aggregates>` — dispatches `Creer<Aggregate>` via `ICommandBus`, returns `201 Created`
     ```csharp
     app.MapPost("/api/<bc>/<aggregates>", async (...) => { ... })
         .WithName("Creer<Aggregate>")
         .WithTags("<BoundedContext>")
         .Produces(StatusCodes.Status201Created)
         .ProducesProblem(StatusCodes.Status400BadRequest);
     ```
   - **GET** `/api/<bc>/<aggregates>/{id:guid}` — dispatches `Obtenir<Aggregate>` via `IQueryBus`, returns `200 OK` or `404 Not Found`
     ```csharp
     app.MapGet("/api/<bc>/<aggregates>/{id:guid}", async (...) => { ... })
         .WithName("Obtenir<Aggregate>")
         .WithTags("<BoundedContext>")
         .Produces<<Aggregate>Dto>()
         .ProducesProblem(StatusCodes.Status404NotFound);
     ```
   - URL path uses **lowercase French plural** (e.g., `/api/tournois/parties`)
   - **`.WithName()` is critical** — it becomes the generated method name in the frontend NSwag client

### Verification

Run `dotnet build` — must compile.
Run `dotnet test` — all tests (unit + E2E) must pass.

### Gate — End of PHASE 5

⛔ **GATE: Stop after wiring is complete and tests pass.**

Present:
- DI registrations added (Write + Read)
- API endpoints created (POST + GET)
- All tests status ✅

Ask:
> *"Wiring terminé. Endpoints : POST /api/<bc>/<aggregates> (via ICommandBus), GET /api/<bc>/<aggregates>/{id} (via IQueryBus). Tous les tests passent. Le scaffold de l'agrégat est terminé — vous pouvez maintenant ajouter la logique métier avec `/task-implement-feature-back`."*

---

## Aggregate Scaffold — Final Report

```
Aggregate Scaffold complete ✅

Bounded context: <BC>
Aggregate: <Aggregate>

Write Domain:
- ValueObjects/<Aggregate>Id.cs — typed Id (ITypedId<Guid>)
- Events/<Aggregate>Cree.cs — creation event (IDomainEvent)
- Aggregates/<Aggregate>.cs — aggregate (AggregateRoot<<Aggregate>Id>)
- Ports/I<Aggregate>Repository.cs — repository port

Write Application:
- Creer<Aggregate>.cs — creation command + handler (ICommand<<Aggregate>Id>)

Write Infrastructure:
- EventStore/Payloads/<Aggregate>CreePayload.cs — event payload
- EventStore/<BC>EventPayloadMapper.cs — updated with new case
- EventStore/StateRebuilders/<Aggregate>StateRebuilder.cs — state rebuilder
- Persistence/EventSourced<Aggregate>Repository.cs — ES repository

Read Application:
- Obtenir<Aggregate>.cs — query + handler + <Aggregate>Dto
- Ports/I<Aggregate>ReadRepository.cs — read repository port

Read Infrastructure:
- Models/<Aggregate>ReadModel.cs — read model
- Configurations/<Aggregate>ReadModelConfiguration.cs — IEntityTypeConfiguration for shared ReadDbContext
- Projections/<Aggregate>CreeProjection.cs — projection
- EfCore<Aggregate>ReadRepository.cs — read repository

Wiring:
- Write ServiceCollectionExtensions — repository + state rebuilder + type alias
- Read ServiceCollectionExtensions — read repository
- API: POST /api/<bc>/<aggregates> → Creer<Aggregate> (via ICommandBus)
- API: GET /api/<bc>/<aggregates>/{id} → Obtenir<Aggregate> (via IQueryBus)

All tests passing ✅
```

---

## Accumulation pattern

When scaffolding a **second or subsequent aggregate** in the same BC, files modified in Phases 3-5 already have content from previous aggregates. Always **append** to existing content — never overwrite:

- `<BC>EventPayloadMapper.cs` — add a new case to the existing switch expression
- `Configurations/` — add a new `IEntityTypeConfiguration<T>` for the new read model
- Write `ServiceCollectionExtensions.cs` — add registrations alongside existing ones
- Read `ServiceCollectionExtensions.cs` — add registrations alongside existing ones
- API endpoints — add new endpoints alongside existing ones

## Naming conventions

| Element | Convention | Example |
|---|---|---|
| Typed Id | `<Aggregate>Id` | `PartieId`, `JoueurId` |
| Creation event | `<Aggregate>Cree` (French past participle) | `PartieCree`, `JoueurCree` |
| Aggregate | French domain noun | `Partie`, `Joueur` |
| Repository port | `I<Aggregate>Repository` | `IPartieRepository` |
| Creation command | `Creer<Aggregate>` | `CreerPartie` |
| Event payload | `<Aggregate>CreePayload` | `PartieCreePayload` |
| State rebuilder | `<Aggregate>StateRebuilder` | `PartieStateRebuilder` |
| ES repository | `EventSourced<Aggregate>Repository` | `EventSourcedPartieRepository` |
| Read model | `<Aggregate>ReadModel` | `PartieReadModel` |
| Read model config | `<Aggregate>ReadModelConfiguration` | `PartieReadModelConfiguration` |
| Projection | `<Aggregate>CreeProjection` | `PartieCreeProjection` |
| Query | `Obtenir<Aggregate>` | `ObtenirPartie` |
| DTO | `<Aggregate>Dto` | `PartieDto` |
| Read repository port | `I<Aggregate>ReadRepository` | `IPartieReadRepository` |
| Read repository impl | `EfCore<Aggregate>ReadRepository` | `EfCorePartieReadRepository` |
| API endpoint (create) | `POST /api/<bc>/<aggregates>` | `POST /api/tournois/parties` |
| API endpoint (get) | `GET /api/<bc>/<aggregates>/{id:guid}` | `GET /api/tournois/parties/{id:guid}` |
| OpenAPI operation (create) | `.WithName("Creer<Aggregate>")` | `.WithName("CreerPartie")` |
| OpenAPI operation (get) | `.WithName("Obtenir<Aggregate>")` | `.WithName("ObtenirPartie")` |
