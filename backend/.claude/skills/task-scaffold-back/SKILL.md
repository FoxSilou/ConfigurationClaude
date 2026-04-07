---
name: task-scaffold-back
description: Scaffolds infrastructure — general foundation, bounded context specific, or aggregate specific
user-invocable: true
argument-hint: "[bounded context name] [aggregate name]"
context: fork
agent: scaffold
---

# /task-scaffold-back -> scaffold agent

Delegates to the `scaffold` agent.

## Usage

```
/scaffold-back                                    -> general scaffolding (Shared.Write.Domain, Shared.Write.Infrastructure, API shell, E2E harness)
/scaffold-back <bounded context name>             -> bounded context scaffolding (persistence, API endpoints, DI, E2E fakes)
/scaffold-back <bounded context name> <aggregate> -> aggregate scaffolding (typed Id, aggregate, event, repository, command, query, projections, wiring)
```

## Modes

### General scaffolding (no argument)

Scaffolds the shared foundation that all bounded contexts depend on:

- **Shared.Write.Domain** — `AggregateRoot<TId>`, `IDomainEvent`, `ITypedId<T>`, `ICommand<T>`, `ICommandBus`, `IQueryBus`, `IEventStore`, `IDomainEventHandler<T>`, `IDomainEventBus`, exceptions
- **Shared.Write.Infrastructure** — MediatR wiring (`MediatRCommandBus`, wrappers, adapters, `AddMessaging()`), ES infra (`IStateRebuilder`, `EventSerializer`, `TypedIdConverterFactory`, `ConcurrencyException`)
- **API composition root** — `Program.cs` shell, error middleware (Problem Details RFC 7807), health endpoint
- **E2E test harness** — project, `WebApplicationFactory`, collection fixture, smoke test
- **Solution structure** — `<SolutionName>.sln` file, project references

### Bounded context scaffolding (with BC name)

Scaffolds the vertical slice for a specific bounded context:

- **Persistence** — event store (WriteDbContext, StateRebuilders, EventSourcedRepository) or EF Core models
- **Port implementations** — adapters for Application ports (`IEmailSender`, `IPasswordHasher`, etc.)
- **Projections** — read-side materialization from events
- **API endpoints** — endpoints using `ICommandBus`, request DTOs, DI registration
- **E2E test fakes** — test doubles for the BC's external ports

### Aggregate scaffolding (with BC name + aggregate name)

Scaffolds the minimal structure for a new aggregate within an existing BC:

- **Write Domain** — Typed Id, creation event, aggregate class (with `Creer` + `Reconstituer`), repository port
- **Write Application** — Creation command + nested handler
- **Write Infrastructure** — Event payload, payload mapper update, state rebuilder, event-sourced repository
- **Read side** — Read model, IEntityTypeConfiguration<T> for shared ReadDbContext, projection, query + DTO, read repository port + implementation
- **Wiring** — DI registration updates (Write + Read), API endpoints (POST + GET)

The aggregate scaffold produces a **minimal aggregate with only an Id** — no business properties. Business logic is added via `/task-implement-feature-back`.

## Examples

```
/scaffold-back
-> General scaffolding: Shared.Write.Domain, Shared.Write.Infrastructure, API shell, E2E harness

/scaffold-back Identite
-> BC scaffolding: event store, state rebuilders, projections, endpoints, DI for Identite

/scaffold-back Tournois
-> BC scaffolding: event store, state rebuilders, projections, endpoints, DI for Tournois

/scaffold-back Tournois Partie
-> Aggregate scaffolding: PartieId, PartieCree event, Partie aggregate, repository, command, query, projections, wiring

/scaffold-back Identite Role
-> Aggregate scaffolding: RoleId, RoleCree event, Role aggregate, repository, command, query, projections, wiring
```

## Constraints

- Never writes business logic — only plumbing code
- Never creates or modifies unit tests
- All existing tests must remain green throughout
- General scaffolding must be done BEFORE any BC scaffolding
- BC scaffolding must be done BEFORE any aggregate scaffolding
- Event Sourcing is the default persistence strategy
- Aggregate scaffold produces only an Id — no business-specific properties

## Suggested follow-up

- After general scaffolding -> `/scaffold-back <BoundedContext>` for each BC
- After BC scaffolding -> `/scaffold-back <BoundedContext> <Aggregate>` for each aggregate
- After aggregate scaffolding -> `/task-implement-feature-back` to add business logic via TDD
