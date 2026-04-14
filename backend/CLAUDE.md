# CLAUDE.md — Backend

ASP.NET Core solution **ImperiumRex** following **Hexagonal Architecture**, **DDD**, and **strict CQRS**.

## Tech Stack

- **Language**: C# (latest stable — currently C# 14)
- **Runtime**: .NET (latest stable — currently .NET 10)
- **Web framework**: ASP.NET Core (Minimal APIs or Controllers)
- **ORM**: Entity Framework Core
- **Database**: SQL Server (default for Event Store and Read Models)
- **Internal messaging**: MediatR — used as an **infrastructure adapter** behind generic interfaces in Shared.Write.Domain
- **Persistence**: Event Sourcing by default (custom SQL event store in `Shared.Write.Infrastructure`), state-based (EF Core) as alternative
- **Time abstraction**: `TimeProvider` (built-in .NET 8+)
- **API contract**: OpenAPI (generated at build via `Microsoft.Extensions.ApiDescription.Server` → `Api.json` at backend root, consumed by frontend NSwag)
- **Tests**: xUnit, FluentAssertions, Testcontainers (SQL Server for E2E)

## Architecture

```
src/
├── Shared/
│   ├── Write/
│   │   ├── Shared.Write.Domain.csproj          → AggregateRoot<TId>, IDomainEvent, ITypedId, ICommand, IQuery,
│   │   │                                         ICommandBus, IQueryBus, IEventStore, IDomainEventHandler<T>,
│   │   │                                         IDomainEventBus, exceptions
│   │   └── Shared.Write.Infrastructure.csproj  → MediatR command/event adapters (MediatRCommandBus, MediatRDomainEventBus,
│   │                                              AddWriteMessaging(), AddDomainEventHandlers()),
│   │                                              ES infra (SqlEventStore, WriteDbContext, StoredEvent, AggregateSnapshot,
│   │                                              IStateRebuilder, EventSerializer, AddEventSourcing(),
│   │                                              IStoredEventPayload, IStoredEventReader, IEventPayloadMapper)
│   └── Read/
│       └── Shared.Read.Infrastructure.csproj   → MediatR query adapters (MediatRQueryBus, AddReadMessaging()),
│                                                  ReadDbContext (shared, single DB <SolutionName>_Read),
│                                                  AddReadDbContext()
├── <BoundedContext>/
│   ├── Write/
│   │   ├── <BC>.Write.Domain.csproj            → Aggregates, Entities, ValueObjects, Events, Ports
│   │   ├── <BC>.Write.Application.csproj       → Commands + Handlers (flat), Behaviors, Ports
│   │   └── <BC>.Write.Infrastructure.csproj    → Adapters (EF Core, EventStore, external services)
│   └── Read/
│       ├── <BC>.Read.Application.csproj        → Queries + Handlers (flat), Ports
│       └── <BC>.Read.Infrastructure.csproj     → Read adapters (read models, IEntityTypeConfiguration<T>, projections)
├── Api/
│   └── Api.csproj                               ← Composition root
tests/
├── <BoundedContext>.UnitTests/
└── ImperiumRex.E2E.Tests/
```

Dependencies flow **inward only**: Api → Application → Domain. Infrastructure → Application → Domain. Domain and Application must **never** reference Infrastructure or Api. Read and Write are **independent stacks**.

**Important**: projects are placed **directly** under `Write/` or `Read/` — no `Domain/`, `Application/`, or `Infrastructure/` subdirectories within them.

## Critical Rules (always apply)

- **Domain code in French** (ubiquitous language). Infrastructure/technical code in English.
- **No untested code**: TDD on Domain and Application. See skill: `tdd-workflow`.
- **MediatR never in Domain or Application** — only Infrastructure.
- **DateTimeOffset everywhere**, never DateTime. Time via `TimeProvider`, never direct clock.
- **No null in the domain**: Result<T> pattern or domain exceptions.
- **Fakes and Stubs only** — no Mocks (no Moq, no NSubstitute).
- **Ports use Value Objects**, never raw primitives.
- **Invariants in private constructor**, not in factory methods.
- **Problem Details (RFC 7807)** for API error responses.
- **Event Sourcing by default** — domain-pure aggregates, custom SQL event store (SQL Server), state rebuilders in Infrastructure.
- **Testcontainers for E2E** — SQL Server containers for isolated E2E tests.

→ Full conventions (naming table, C# style, Always/Never checklist): see skill `backend-conventions`
→ TDD discipline: see skill `tdd-workflow`
→ Unit testing conventions: see skill `unit-testing`
→ E2E testing conventions: see skill `e2e-testing`
→ Event Sourcing pattern (domain-pure aggregates, custom SQL event store, projections): see skill `event-sourcing`

## Pattern Rules (auto-loaded)

Les fichiers ci-dessous sont chargés automatiquement et font autorité sur leurs concepts respectifs.

@.claude/rules/aggregate.md
@.claude/rules/command.md
@.claude/rules/cqrs.md
@.claude/rules/domain-event.md
@.claude/rules/efcore.md
@.claude/rules/entity.md
@.claude/rules/error-handling.md
@.claude/rules/event-sourcing.md
@.claude/rules/identity-framework.md
@.claude/rules/mediatr.md
@.claude/rules/pipeline-behavior.md
@.claude/rules/port-repository.md
@.claude/rules/query.md
@.claude/rules/read-model.md
@.claude/rules/shared-kernel.md
@.claude/rules/value-object.md

## Ownership Matrix — concept → propriétaire

Un seul fichier fait autorité par concept. Les autres peuvent **référencer** mais pas redéfinir. En cas de conflit, le propriétaire gagne.

| Concept | Propriétaire (autorité) | Supporters (référencent) |
|---|---|---|
| Aggregate Root (base, invariants, events) | `rules/aggregate.md` | `rules/entity.md`, `skill: event-sourcing` |
| Entity (private ctor, factories, Reconstituer) | `rules/entity.md` | `rules/aggregate.md` |
| Value Object (readonly record struct, Creer/Reconstituer) | `rules/value-object.md` | `rules/entity.md` |
| Command (structure, naming, nested Handler) | `rules/command.md` | `rules/cqrs.md`, `rules/mediatr.md` |
| Query (structure, naming, Read stack) | `rules/query.md` | `rules/cqrs.md`, `rules/read-model.md` |
| CQRS séparation Read/Write | `rules/cqrs.md` | `rules/command.md`, `rules/query.md`, `rules/read-model.md` |
| Read Model (DTOs, read repos, Read infra) | `rules/read-model.md` | `rules/query.md` |
| Domain Event (naming, factory Creer, OccurredOn) | `rules/domain-event.md` | `rules/aggregate.md`, `rules/event-sourcing.md` |
| Event Sourcing (State Rebuilder, versioning, upcasters) | `rules/event-sourcing.md` | `skill: event-sourcing` (guide usage) |
| MediatR comme adapter d'infra | `rules/mediatr.md` | `rules/command.md`, `rules/query.md`, `rules/pipeline-behavior.md` |
| Pipeline Behaviors (Validation, Logging, Transaction) | `rules/pipeline-behavior.md` | `rules/mediatr.md` |
| Ports & Repositories (interfaces, adapters, naming) | `rules/port-repository.md` | — |
| EF Core persistence models (attributs, ToDomain/FromDomain) | `rules/efcore.md` | `rules/read-model.md` |
| Error handling (DomainException, Result<T>, Problem Details) | `rules/error-handling.md` | — |
| Shared.Write.Domain (contrat partagé, zéro dép) | `rules/shared-kernel.md` | toutes les rules (base types) |
| ASP.NET Core Identity (hybrid, projections, JWT, seed) | `rules/identity-framework.md` | `rules/port-repository.md` |
| Conventions C# (naming, style, Always/Never) | `skill: backend-conventions` | — |
| TDD discipline (RED/GREEN/REFACTOR, TPP) | `skill: tdd-workflow` | — |
| Unit testing (Classical, fakes, AAA, <Command>Doit_) | `skill: unit-testing` | — |
| E2E testing (Testcontainers, WebAppFactory) | `skill: e2e-testing` | — |

**Règle d'ajout** : avant de documenter un concept dans un nouveau fichier, vérifier qu'il n'existe pas déjà un propriétaire. Si oui → éditer le propriétaire. Sinon → créer la rule/skill et ajouter une ligne dans cette matrice.

## Rapports d'exécution — pas de duplication

Les agents `scaffold`, `implement-feature`, `fix-bug`, `refactor` **ne doivent PAS créer de rapport séparé** sous `docs/scaffold-*.md`, `docs/feature-*.md`, etc. quand un fichier `docs/story-mapping/<projet>/progression.md` existe. Le bilan complet vit :

1. dans la section `## Bilans` de `progression.md` (historique horodaté, source unique de vérité) ;
2. dans le message de retour à l'orchestrateur (résumé immédiat).

Voir workspace `CLAUDE.md` section « Reprise post-reset » et le skill `/task-resume` pour la convention complète.

## Slash Commands

| Command | Description |
|---|---|
| `/task-scaffold-back` | Infrastructure scaffolding (general foundation, BC-specific, or aggregate-specific) |
| `/task-implement-feature-back` | TDD step-by-step with user gates |
| `/task-implement-feature-auto-back` | TDD autonomous mode |
| `/task-fix-bug-back` | Test-first bug fixing |
| `/task-refactor-back` | Iso-functional refactoring |

## Useful Commands

```bash
dotnet build
dotnet test
dotnet test --collect:"XPlat Code Coverage"
# Write migrations (shared WriteDbContext)
dotnet ef migrations add <n> --project src/Shared/Write/Shared.Write.Infrastructure --startup-project src/Api --context WriteDbContext --output-dir EventStore/Migrations
dotnet ef database update --project src/Shared/Write/Shared.Write.Infrastructure --startup-project src/Api --context WriteDbContext
# Read migrations (shared ReadDbContext)
dotnet ef migrations add <n> --project src/Shared/Read/Shared.Read.Infrastructure --startup-project src/Api --context ReadDbContext --output-dir Migrations
dotnet ef database update --project src/Shared/Read/Shared.Read.Infrastructure --startup-project src/Api --context ReadDbContext
dotnet format
```
