# MODE 2 — BOUNDED CONTEXT SCAFFOLDING

Use this mode when a bounded context name is provided.

**Prerequisite**: General scaffolding (Mode 1) must be completed. If Shared.Write.Domain, Shared.Write.Infrastructure, or the API shell do not exist, inform the user and suggest running general scaffolding first.

### Event Sourcing Support

Event Sourcing is the **default persistence strategy**. If the user explicitly asks for state-based persistence (e.g., `@scaffold Parties --state-based`), use EF Core models instead.

For event-sourced BCs (default):
- **No EF Core persistence models** for the aggregate — events are the persistence mechanism.
- **`WriteDbContext`, `StoredEvent`, `AggregateSnapshot`, `SqlEventStore`** are **shared** (in `Shared.Write.Infrastructure`) — not created per-BC.
- **BC Infrastructure** uses `EventSourced<Aggregate>Repository` and a `<Aggregate>StateRebuilder` (per aggregate).
- **Projections**: `<Event>Projection` classes implementing `IDomainEventHandler<TEvent>` in Read Infrastructure for read-side materialization.
- **ReadDbContext** is shared (in `Shared.Read.Infrastructure`) — each BC registers its read models via `IEntityTypeConfiguration<T>`.
- The **domain layer is identical** to state-based — the aggregate uses `AggregateRoot<TId>` and `Reconstituer` as usual.

The diagnostic (Phase 0) must detect whether the BC targets event sourcing or state-based and adjust the checklist accordingly.

## Workflow — Bounded Context

```
PHASE 0 — DIAGNOSTIC
  ↓ (user gate)
PHASE 1 — INFRASTRUCTURE (persistence, port implementations, messaging)
  ↓ (user gate)
PHASE 2 — API (endpoints, DI, middleware — endpoints use ICommandBus)
  ↓ (user gate)
PHASE 3 — E2E TEST FAKES
  ↓ (user gate)
SMOKE TEST — everything compiles, existing tests pass
  ↓
BC SCAFFOLD COMPLETE ✅
```

---

## BC — PHASE 0 — DIAGNOSTIC

### Goal

Inventory what exists and what is missing for this bounded context.

### Steps

1. **Verify prerequisites**: Shared.Write.Domain, Shared.Write.Infrastructure, API shell must exist. If not → stop and inform user.
2. Read the current solution structure (all `.csproj` files, folder structure).
3. Identify **implemented domain concepts** (entities, value objects, aggregates, events) — look in `<BC>/Write/<BC>.Write.Domain/`.
4. Identify **implemented application concepts** (commands, queries, ports) — look in `<BC>/Write/<BC>.Write.Application/`, `<BC>/Read/<BC>.Read.Application/`.
5. Check for each infrastructure concern:

| Concern | What to check | Location |
|---|---|---|
| **WriteDbContext (shared)** | Does it exist in `Shared.Write.Infrastructure`? | `Shared/Write/Shared.Write.Infrastructure/EventStore/` |
| **EventPayloadMapper** | Does the BC have an `IEventPayloadMapper` implementation? | `<BC>/Write/<BC>.Write.Infrastructure/EventStore/<BC>EventPayloadMapper.cs` |
| **State rebuilders** | Does each event-sourced aggregate have a StateRebuilder? | `<BC>/Write/<BC>.Write.Infrastructure/EventStore/StateRebuilders/` |
| **Persistence models** | (state-based only) Does each aggregate have a persistence model? | `<BC>/Write/<BC>.Write.Infrastructure/Persistence/Models/` |
| **Repository implementations** | Does each `I<Name>Repository` have an adapter? | `<BC>/Write/<BC>.Write.Infrastructure/Persistence/` |
| **Projections** | Do projections exist for read models? | `<BC>/Write/<BC>.Write.Infrastructure/Projections/` |
| **Port implementations** | Does each port in `Application/Ports/` have an adapter? | `<BC>/Write/<BC>.Write.Infrastructure/` |
| **DI registration** | Are all BC services registered in Program.cs? | `src/Api/Program.cs` |
| **API endpoints** | Do endpoints exist for all commands/queries? Do they inject `ICommandBus`? | `src/Api/` or `<BC>/.../Api/` |
| **E2E test fakes** | Do test doubles exist for BC-specific external ports? | `tests/` |

6. Produce the diagnostic document.

### Diagnostic Document

Save to: `docs/scaffold-<bounded-context>-<date>.md`

```markdown
# Scaffold Diagnostic: <bounded context>

## Persistence Strategy
Event Sourcing / State-based

## Implemented Domain Concepts
- Aggregates: <list>
- Value Objects: <list>
- Domain Events: <list>

## Implemented Application Concepts
- Commands: <list>
- Queries: <list>
- Ports: <list>

## Infrastructure Status

| Concern | Status | Details |
|---|---|---|
| WriteDbContext (shared) | ✅ / ❌ | <in Shared.Write.Infrastructure> |
| State rebuilders | ✅ / ❌ | <if ES> |
| Persistence models | ✅ / ❌ | <if state-based> |
| Repository implementations | ✅ / ❌ | <details> |
| Projections | ✅ / ❌ | <if ES> |
| Port implementations | ✅ / ❌ | <details> |
| DI registration | ✅ / ❌ | <details> |
| API endpoints | ✅ / ❌ | <use ICommandBus?> |
| E2E test fakes | ✅ / ❌ | <details> |

## Work Plan
1. <what to create — phase 1>
2. <what to create — phase 2>
3. <what to create — phase 3>
```

### Gate — End of PHASE 0

⛔ **GATE: Stop after producing the diagnostic document.**

Ask:
> *"Diagnostic terminé. Voici ce qui manque : [résumé]. Le plan de travail vous convient-il ? Confirmez pour commencer, ou ajustez."*

Wait for explicit user confirmation.

---

## BC — PHASE 1 — INFRASTRUCTURE

### Goal

Create the persistence layer and port implementations for this bounded context.

### Steps (in order)

#### 1. Identity Setup (if Identité bounded context)

**⚠️ Non-interactif** — si le nom du BC est `Identite` (ou variante `Identity`), appliquer **intégralement** le pattern défini dans `identity-framework.md` : ASP.NET Identity + JWT + lockout + rate limiting + `AdministrateurSeeder` stubbé `NotImplementedException` + projections Identity/email + ports sécurité (`IPasswordHasher`, `ITokenGenerator`, `IUtilisateurAuthReader`, `ILoginAttemptTracker`, `ICurrentUserAccessor`, `IEmailSender`). **Ne pas demander à l'utilisateur « full vs minimal »** — la rule prescrit le pattern complet sans option. La seule situation où l'Identity Setup est sauté : `identity-framework.md` volontairement hors scope du projet (aucune feature auth dans le story-map) — auquel cas l'utilisateur doit l'avoir explicité avant.

If the bounded context involves user authentication, follow rule `identity-framework.md` for the full hybrid Identity pattern. Key steps:

- Create `ApplicationUser`, `AppIdentityDbContext`, `IdentityDataSeeder` (infra layer, shares Read DB)
- Create Identity projections syncing domain events → Identity tables via `UserManager`
- For JWT: create `ITokenGenerator`, `IUtilisateurAuthReader` ports + infrastructure implementations
- Create `AdministrateurSeeder` (infra layer) — seed event-sourced via `ICommandBus` (`InscrireUtilisateur` → `ConfirmerEmail` → `AttribuerRole`). Config via section `IdentitySeed` (`Email`, `Pseudonyme`) dans `appsettings.json` + password via user-secrets / env var `IdentitySeed__Password`. Invoqué depuis `Program.cs` **juste après** `IdentityDataSeeder.EnsureIdentityDatabaseAsync`, dans le même scope DI. Voir rule `identity-framework.md` § "Seed administrateur" pour la séquence complète et les guards d'idempotence.
  - ⚠️ **Ordonnancement** : les commandes `InscrireUtilisateur`/`ConfirmerEmail`/`AttribuerRole` sont produites par `/task-implement-feature-back`, pas par le scaffold. Au scaffold BC, créer le seeder avec `throw new NotImplementedException(...)` comme corps, câbler appel + config + `Program.cs` immédiatement, et finaliser la séquence après l'implémentation TDD des 3 commandes. Voir rule `identity-framework.md` § "Ordonnancement scaffold ↔ feature".

See the rule for the complete checklist, naming conventions, and common mistakes to avoid.

**Security hardening** (see rule `identity-framework.md` § Sécurité basique):
- Activate `Lockout` options in `AddIdentity<>()` (15 min lockout, 5 attempts max)
- Create port `ILoginAttemptTracker` (Application/Ports) with `EstVerrouilleAsync`, `EnregistrerEchecAsync`, `ReinitialiserAsync`
- Create adapter `IdentityLoginAttemptTracker` (Infrastructure/Adapters) delegating to `UserManager`
- Enforce password policy in `MotDePasse` VO (min 8 chars, 1 uppercase, 1 digit, 1 special) + synchronize Identity `Password` options
- Register `AddRateLimiter()` in DI (reminder for Phase 2 API: apply `RequireRateLimiting("auth")` on auth endpoints)

#### 2. Event Sourcing Infrastructure (default)

Follow the `event-sourcing` skill:

- **`WriteDbContext`, `StoredEvent`, `AggregateSnapshot`, `SqlEventStore`** are already in `Shared.Write.Infrastructure` — do NOT recreate per-BC
- **BC Infrastructure/EventStore/<BC>EventPayloadMapper.cs**: create the per-BC payload mapper implementing `IEventPayloadMapper`. Start with an empty switch expression — cases are added later when aggregates are scaffolded (Mode 3):
  ```csharp
  internal sealed class <BC>EventPayloadMapper : IEventPayloadMapper
  {
      public IStoredEventPayload ToPayload(IDomainEvent @event) => @event switch
      {
          _ => throw new InvalidOperationException($"Unknown event type: {@event.GetType().Name}")
      };
  }
  ```
- **BC Infrastructure/EventStore/StateRebuilders/**: create `<Aggregate>StateRebuilder` — folds payloads, calls `Reconstituer`
- **BC Infrastructure/Persistence/**: create `EventSourced<Aggregate>Repository` (NOT `EfCore<Aggregate>Repository`)
- **Read Infrastructure/Projections/**: create `<Event>Projection` classes implementing `IDomainEventHandler<TEvent>` — one per event type
- **Read side**: create read models in `<BC>.Read.Infrastructure/Models/` and `IEntityTypeConfiguration<T>` for each read model (registered in the shared `ReadDbContext` from `Shared.Read.Infrastructure`)

#### 3. State-based Infrastructure (only if explicitly requested)

Follow rule `efcore.md` for persistence models (`ToDomain()` / `FromDomain()`), `AppDbContext`, and `EfCore<Aggregate>Repository`.

#### 4. Port Implementations

For each port in `Application/Ports/` without an adapter — follow rule `port-repository.md` (signatures use Value Objects, not primitives). For scaffolding, create simple stub implementations (e.g., `ConsoleEmailSender`).

### Verification

Run `dotnet build` — everything must compile.
Run `dotnet test` — all existing tests must remain green.

### Gate — End of PHASE 1

⛔ **GATE: Stop after creating all infrastructure implementations.**

Present:
- Files created (list with paths)
- Build status ✅
- Existing tests status ✅

Ask:
> *"Infrastructure créée. Tout compile et les tests existants passent. Confirmez pour passer au câblage API."*

---

## BC — PHASE 2 — API

### Goal

Wire the API endpoints and dependency injection for this bounded context.

### Steps (in order)

#### 1. Dependency Injection

Wire all BC services in `Program.cs` (or a dedicated extension class):

- `AddEventSourcing(connectionString, domainAssemblies)` — registers shared WriteDbContext + SqlEventStore (if not already registered)
- `AddReadDbContext(connectionString, readInfraAssemblies)` — registers shared ReadDbContext (if not already registered), pass the BC's Read.Infrastructure assembly
- Identity services (if applicable)
- Repository implementations → their interfaces
- State rebuilders (if ES)
- **`builder.Services.AddDomainEventHandlers(typeof(SomeProjectionInBC).Assembly)`** for this BC's event handlers (projections)
- Port implementations → their interfaces
- **`builder.Services.AddWriteMessaging(typeof(SomeCommandInBC).Assembly)`** for this BC's command handlers
- **`builder.Services.AddReadMessaging(typeof(SomeQueryInBC).Assembly)`** for this BC's query handlers
- **DO NOT register individual handlers manually** — `AddWriteMessaging()` / `AddReadMessaging()` do this automatically

#### 2. API Endpoints

For each command/query that needs HTTP exposure:

- Create an endpoint in the Api layer
- **Inject `ICommandBus`** — never individual handlers (rule `mediatr.md`)
- The endpoint does **only** orchestration:
  1. Deserialize the HTTP request
  2. Create the command/query
  3. Dispatch via `ICommandBus`
  4. Map the result to an HTTP response
- **Never put business logic in endpoints**
- **OpenAPI annotations are MANDATORY** on every endpoint:
  - `.WithName("<OperationName>")` — operation ID used by NSwag to generate typed method names in the frontend client
  - `.WithTags("<BoundedContext>")` — groups endpoints in the spec
  - `.Produces<T>(statusCode)` — documents the success response type
  - `.ProducesProblem(statusCode)` — documents error responses (Problem Details)
  
  Example:
  ```csharp
  app.MapPost("/api/<bc>/<aggregates>", async (...) => { ... })
      .WithName("Creer<Aggregate>")
      .WithTags("<BoundedContext>")
      .Produces(StatusCodes.Status201Created)
      .ProducesProblem(StatusCodes.Status400BadRequest);
  ```
  
  Without these annotations, the frontend NSwag client cannot generate meaningful method names or typed responses.

#### 3. Request/Response Models

If the API needs DTOs for input:
- Create request models in the Api layer (not in Domain or Application)
- Map from request model to command/query in the endpoint

### Verification

Run `dotnet build` — everything must compile.
Run `dotnet test` — all existing tests must remain green.

### Gate — End of PHASE 2

⛔ **GATE: Stop after wiring the API layer.**

Present:
- Endpoints created (method + path + ICommandBus dispatch)
- DI registrations
- Build status ✅
- Existing tests status ✅

Ask:
> *"API câblée. Endpoints : [liste]. Tous utilisent ICommandBus pour le dispatch. Confirmez pour créer les fakes E2E."*

---

## BC — PHASE 3 — E2E TEST FAKES

### Goal

Create test doubles for this bounded context's external ports so E2E tests can be written.

### Steps

1. Create test fakes for BC-specific external ports:
   - **`FakeEmailSenderE2E : IEmailSender`** — captures sent emails using **Value Object parameters**
   - Other port fakes as needed — all matching the port signatures (which use Value Objects)

2. Register fakes in the `E2EFixture` (WebApplicationFactory):
   - Replace external service ports with test doubles

3. Verify the existing smoke test still passes with the new registrations.

### Verification

Run `dotnet test` — all tests (unit + E2E) must pass.

### Gate — End of PHASE 3

⛔ **GATE: Stop after fakes are created and tests pass.**

Present:
- E2E fakes created (list with paths)
- All tests status ✅

Ask:
> *"Fakes E2E en place. Tous les tests passent. Le scaffold du bounded context est terminé — vous pouvez maintenant écrire les tests E2E pour vos features avec `/implement-feature`."*

---

## BC Scaffold — Final Report

```
BC Scaffold complete ✅

Bounded context: <name>
Persistence strategy: Event Sourcing / State-based

Infrastructure created:
- <file>: <description>

API endpoints wired:
- <METHOD> <path> → <command> (via ICommandBus)

E2E test fakes:
- <list of fakes>

All tests passing:
- Unit tests: <count> ✅
- E2E tests: <count> ✅
```

---

## Structure Reference

See the Architecture section in `backend/CLAUDE.md` and rule `cqrs.md` for the full project structure.

Key reminders:
- **Projects directly under Write/ or Read/** — no Domain/, Application/, Infrastructure/ subdirectories
- **Read and Write never reference each other** — shared abstractions live in `Shared.Write.Domain`
