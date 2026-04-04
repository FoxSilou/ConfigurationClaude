# CLAUDE.md — Backend

ASP.NET Core solution **ImperiumRex** following **Hexagonal Architecture**, **DDD**, and **strict CQRS**.

## Tech Stack

- **Language**: C# (latest stable — currently C# 14)
- **Runtime**: .NET (latest stable — currently .NET 10)
- **Web framework**: ASP.NET Core (Minimal APIs or Controllers)
- **ORM**: Entity Framework Core
- **Internal messaging**: MediatR — used as an **infrastructure adapter** behind generic interfaces in Shared.Write.Domain
- **Persistence**: Event Sourcing by default (custom SQL event store), state-based (EF Core) as alternative
- **Time abstraction**: `TimeProvider` (built-in .NET 8+)
- **Tests**: xUnit, FluentAssertions

## Architecture

```
src/
├── Shared/
│   ├── Write/
│   │   ├── Shared.Write.Domain.csproj          → AggregateRoot<TId>, IDomainEvent, ITypedId, ICommand, IQuery,
│   │   │                                         ICommandBus, IQueryBus, IEventStore, IProjection, exceptions
│   │   └── Shared.Write.Infrastructure.csproj  → MediatR command adapters (MediatRCommandBus, AddWriteMessaging()),
│   │                                              ES infra (IStateRebuilder, EventSerializer, TypedIdConverterFactory)
│   └── Read/
│       └── Shared.Read.Infrastructure.csproj   → MediatR query adapters (MediatRQueryBus, AddReadMessaging())
├── <BoundedContext>/
│   ├── Write/
│   │   ├── <BC>.Write.Domain.csproj            → Aggregates, Entities, ValueObjects, Events, Ports
│   │   ├── <BC>.Write.Application.csproj       → Commands + Handlers (flat), Behaviors, Ports
│   │   └── <BC>.Write.Infrastructure.csproj    → Adapters (EF Core, EventStore, external services)
│   └── Read/
│       ├── <BC>.Read.Application.csproj        → Queries + Handlers (flat), Ports
│       └── <BC>.Read.Infrastructure.csproj     → Read adapters (Dapper, ReadDbContext, projections)
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
- **Event Sourcing by default** — domain-pure aggregates, custom SQL event store, state rebuilders in Infrastructure.

→ Full conventions (naming table, C# style, Always/Never checklist): see skill `backend-conventions`
→ TDD discipline: see skill `tdd-workflow`
→ Unit testing conventions: see skill `unit-testing`
→ E2E testing conventions: see skill `e2e-testing`
→ Event Sourcing pattern (domain-pure aggregates, custom SQL event store, projections): see skill `event-sourcing`

## Slash Commands

| Command | Description |
|---|---|
| `/task-scaffold-back` | Infrastructure scaffolding (general foundation or BC-specific) |
| `/task-implement-feature-back` | TDD step-by-step with user gates |
| `/task-implement-feature-auto-back` | TDD autonomous mode |
| `/task-fix-bug-back` | Test-first bug fixing |
| `/task-refactor-back` | Iso-functional refactoring |

## Useful Commands

```bash
dotnet build
dotnet test
dotnet test --collect:"XPlat Code Coverage"
dotnet ef migrations add <n> --project src/<BC>/Write/<BC>.Write.Infrastructure --startup-project src/Api
dotnet ef database update --project src/<BC>/Write/<BC>.Write.Infrastructure --startup-project src/Api
dotnet format
```
