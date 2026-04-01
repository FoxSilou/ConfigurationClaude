---
name: scaffold-back
description: Scaffold infrastructure — general foundation or bounded context specific
user-invocable: true
argument-hint: "[bounded context name]"
context: fork
agent: scaffold
---

# /scaffold-back -> scaffold agent

Delegates to the `scaffold` agent.

## Usage

```
/scaffold-back                        -> general scaffolding (SharedKernel, messaging, API shell, E2E harness)
/scaffold-back <bounded context name> -> bounded context scaffolding (persistence, API endpoints, DI, E2E fakes)
```

## Modes

### General scaffolding (no argument)

Scaffolds the shared foundation that all bounded contexts depend on:

- **SharedKernel** — `AggregateRoot<TId>`, `IDomainEvent`, `ICommand<T>`, `ICommandBus`, `IQueryBus`, exceptions
- **Messaging infrastructure** — MediatR wiring (`MediatRCommandBus`, wrappers, adapters, `AddMessaging()`)
- **API composition root** — `Program.cs` shell, error middleware (Problem Details RFC 7807), health endpoint
- **E2E test harness** — project, `WebApplicationFactory`, collection fixture, smoke test
- **Solution structure** — `.sln` file, project references

### Bounded context scaffolding (with argument)

Scaffolds the vertical slice for a specific bounded context:

- **Persistence** — models, DbContext registration, repository implementations
- **Port implementations** — adapters for Application ports (`IEmailSender`, `IPasswordHasher`, etc.)
- **API endpoints** — endpoints using `ICommandBus`, request DTOs, DI registration
- **E2E test fakes** — test doubles for the BC's external ports

## Examples

```
/scaffold-back
-> General scaffolding: SharedKernel, messaging, API shell, E2E harness

/scaffold-back Identite
-> BC scaffolding: persistence, endpoints, DI for Identite

/scaffold-back Tournois
-> BC scaffolding: persistence, endpoints, DI for Tournois
```

## Constraints

- Never writes business logic — only plumbing code
- Never creates or modifies unit tests
- All existing tests must remain green throughout
- General scaffolding must be done BEFORE any BC scaffolding

## Suggested follow-up

- After general scaffolding -> `/scaffold-back <BoundedContext>` for each BC
- After BC scaffolding -> `/implement-feature` Phase 2 (E2E)
