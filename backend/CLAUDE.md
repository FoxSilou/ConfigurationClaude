# CLAUDE.md — Backend

ASP.NET Core solution following **Hexagonal Architecture**, **DDD**, and **strict CQRS**.

## Tech Stack

- **Language**: C# (latest stable — currently C# 14)
- **Runtime**: .NET (latest stable — currently .NET 10)
- **Web framework**: ASP.NET Core (Minimal APIs or Controllers)
- **ORM**: Entity Framework Core
- **Internal messaging**: MediatR — used as an **infrastructure adapter** behind generic interfaces in SharedKernel
- **Time abstraction**: `TimeProvider` (built-in .NET 8+)
- **Tests**: xUnit, FluentAssertions

## Architecture

```
src/
├── <BoundedContext>/
│   ├── Write/
│   │   ├── Domain/           → Aggregates, Entities, ValueObjects, Events, Ports
│   │   ├── Application/      → Commands + Handlers (flat), Behaviors, Ports
│   │   ├── Infrastructure/   → Adapters (EF Core, MediatR, external services)
│   │   └── Api/              → Endpoints
│   └── Read/
│       ├── Application/      → Queries + Handlers (flat), Ports
│       ├── Infrastructure/   → Read adapters (Dapper, read DbContext)
│       └── Api/              → Endpoints
├── SharedKernel/             → AggregateRoot<TId>, ICommand, IQuery, ICommandBus, IQueryBus
└── Api/
    └── Program.cs            ← Composition root
tests/
├── <BoundedContext>.Write.Application.UnitTests/
├── <BoundedContext>.Read.Application.UnitTests/
└── <SolutionName>.E2E.Tests/
```

Dependencies flow **inward only**: Api → Application → Domain. Infrastructure → Application → Domain. Domain and Application must **never** reference Infrastructure or Api. Read and Write are **independent stacks**.

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

→ Full conventions (naming table, C# style, Always/Never checklist): see skill `backend-conventions`
→ TDD discipline: see skill `tdd-workflow`
→ Unit testing conventions: see skill `unit-testing`
→ E2E testing conventions: see skill `e2e-testing`
→ Event Sourcing pattern (domain-pure aggregates, custom SQL event store, projections): see skill `event-sourcing`

## Slash Commands

| Command | Description |
|---|---|
| `/scaffold-back` | Infrastructure scaffolding (general foundation or BC-specific) |
| `/implement-feature-back` | TDD step-by-step with user gates |
| `/implement-feature-auto-back` | TDD autonomous mode |
| `/fix-bug-back` | Test-first bug fixing |
| `/refactor-back` | Iso-functional refactoring |

## Useful Commands

```bash
dotnet build
dotnet test
dotnet test --collect:"XPlat Code Coverage"
dotnet ef migrations add <n> --project src/<BC>/Write/Infrastructure --startup-project src/Api
dotnet ef database update --project src/<BC>/Write/Infrastructure --startup-project src/Api
dotnet format
```
