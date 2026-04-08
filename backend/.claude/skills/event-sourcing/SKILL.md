---
name: event-sourcing
description: >
  Event Sourcing pattern for .NET/C# projects following Hexagonal Architecture, DDD, and strict CQRS.
  Covers: domain-pure event-sourced aggregates (no ES awareness in domain layer), custom SQL event store
  (SQL Server by default, PostgreSQL variant documented), snapshots, and read-side projections.
  Integrates with existing Shared.Write.Domain abstractions (AggregateRoot, IDomainEvent, ICommand/IQuery buses, ITypedId).

  Use this skill whenever the user mentions event sourcing, event store, event-sourced aggregates, projections
  from events, replaying events, aggregate reconstitution from events, snapshots, or asks to persist an aggregate
  as a stream of events instead of state. Also trigger when the user wants to convert an existing state-based
  aggregate to event sourcing, or when scaffolding a new bounded context that should use event sourcing.
---

# Event Sourcing Skill

## Philosophy

Event Sourcing stores **what happened** rather than **what the current state is**. Each state change is captured as an immutable domain event appended to a stream. The aggregate's current state is rebuilt by replaying its events.

This approach gives you a complete audit trail, enables temporal queries, simplifies debugging (you can see exactly how the state was built), and naturally fits with CQRS — events on the write side feed projections on the read side.

> **Constraints** (domain purity, event immutability, version tracking, round-trip testing, naming) are enforced by the rule `event-sourcing.md` — always loaded, not repeated here.

## How this integrates with the existing architecture

The existing architecture already has strong foundations for Event Sourcing:

- `AggregateRoot<TId>` collects domain events via `RaiseDomainEvent()` — in ES, these same events become the source of truth for persistence.
- `IDomainEvent` with `OccurredOn` is the contract every event implements — no changes needed.
- Domain events are `sealed record` types — immutable by design, perfect for an append-only store.
- `Reconstituer` is the persistence factory — in ES, the StateRebuilder calls it with the replayed state.
- The repository interface (`IPartieRepository`) stays identical — only the Infrastructure adapter changes from `EfCorePartieRepository` to `EventSourcedPartieRepository`.
- CQRS is already strict (separate Read/Write stacks) — projections are just a formalization of the Read side.

The event sourcing mechanics live entirely in Infrastructure:
1. An `IStateRebuilder<TAggregate, TId>` interface in `Shared.Write.Infrastructure`
2. One concrete `StateRebuilder` per event-sourced aggregate (Infrastructure, per BC)
3. An `ITypedId<TPrimitive>` interface in `Shared.Write.Domain` — implemented by all Typed Ids, used by the `Reconstituer` pattern
4. Shared infrastructure types (event store, serializer, payload interfaces) in `Shared.Write.Infrastructure`

## When to use Event Sourcing vs state-based persistence

Event Sourcing is the **default** persistence strategy for new bounded contexts, but it is a deliberate choice per bounded context.

**Good fit**: audit requirements, complex state transitions, temporal queries needed, collaborative domains with conflict resolution, domains where "how we got here" matters as much as "where we are".

**Poor fit**: simple CRUD, mostly static reference data, aggregates with very large state and few events, reporting-heavy contexts where the read model is the primary concern.

A single solution can mix both approaches — some BCs event-sourced, others state-based. The repository interface abstraction makes this transparent to the Application layer.

## Aggregate pattern for Event Sourcing

Read `references/aggregate-es.md` for the complete pattern including:
- The domain-pure aggregate (unchanged from state-based)
- The `StateRebuilder` pattern (Infrastructure fold that calls `Reconstituer`)
- Event-sourced repository with version tracking (without polluting the aggregate)
- Snapshot support via `Reconstituer` parameters
- Trade-offs vs the Apply/When approach
- Round-trip testing strategy
- Migration path from state-based to event-sourced (domain untouched)

## Custom SQL Event Store

Read `references/event-store-custom.md` for the persistence layer including:
- Database schema — **SQL Server by default**, PostgreSQL variant documented where syntax differs
- `IEventStore` port and SQL implementation
- Optimistic concurrency via expected version (managed by repository, not aggregate)
- Snapshot strategy and implementation
- Serialization approach (System.Text.Json with primitive payloads, no custom converters)
- EF Core integration for the event store tables

## Projections and Read Models

Read `references/projections.md` for the read-side materialization including:
- Projection pattern — event handlers that build read models
- Inline projections (synchronous, same transaction) vs async projections
- Projection rebuilding strategy
- Checkpoint tracking for async projections
- Integration with the existing Read stack (ReadDbContext, DTOs, query handlers)

## Directory structure for an event-sourced bounded context

```
src/
├── Shared/
│   ├── Write/
│   │   ├── Shared.Write.Domain.csproj                 ← Pure C#, zero dependencies
│   │   │   ├── ITypedId.cs
│   │   │   ├── Abstractions/
│   │   │   │   ├── IEventStore.cs
│   │   │   │   ├── IDomainEventHandler.cs
│   │   │   │   └── IDomainEventBus.cs
│   │   │   └── Exceptions/
│   │   │       └── DomainException.cs
│   │   └── Shared.Write.Infrastructure.csproj         ← Technical, references Shared.Write.Domain
│   │       ├── Exceptions/
│   │       │   └── ConcurrencyException.cs
│   │       ├── EventStore/
│   │       │   ├── IStateRebuilder.cs
│   │       │   ├── IStoredEventPayload.cs
│   │       │   ├── IStoredEventReader.cs
│   │       │   └── IEventPayloadMapper.cs
│   │       └── Serialization/
│   │           └── EventSerializer.cs
│   └── Read/                                           ← Created when needed
└── <BoundedContext>/
    ├── Write/
    │   ├── <BC>.Write.Domain.csproj
    │   │   ├── Aggregates/
    │   │   │   └── Partie.cs                           ← Standard AggregateRoot<PartieId>
    │   │   ├── Events/
    │   │   │   ├── PartieCree.cs
    │   │   │   ├── JoueurRejoint.cs
    │   │   │   └── PartieDemarree.cs
    │   │   ├── ValueObjects/
    │   │   └── Ports/
    │   │       └── IPartieRepository.cs                ← Same interface as state-based
    │   ├── <BC>.Write.Application.csproj
    │   │   ├── CreerPartie.cs                          ← Command + Handler, unchanged
    │   │   └── Behaviors/
    │   └── <BC>.Write.Infrastructure.csproj
    │       ├── EventStore/
    │       │   ├── Models/
    │       │   │   ├── StoredEvent.cs
    │       │   │   └── AggregateSnapshot.cs
    │       │   └── StateRebuilders/
    │       │       └── PartieStateRebuilder.cs         ← Folds events → calls Reconstituer
    │       └── Persistence/
    │           └── EventSourcedPartieRepository.cs
    └── Read/
        ├── <BC>.Read.Application.csproj
        │   ├── ObtenirPartie.cs
        │   └── Ports/
        └── <BC>.Read.Infrastructure.csproj
            ├── Configurations/
            │   └── PartieReadModelConfiguration.cs     ← IEntityTypeConfiguration for shared ReadDbContext
            ├── Projections/
            │   ├── PartieCreeProjection.cs              ← IDomainEventHandler<PartieCree>
            │   └── JoueurRejointProjection.cs           ← IDomainEventHandler<JoueurRejoint>
            └── ReadModels/
                └── PartieReadModel.cs
```

## Key decisions

> Naming conventions, event immutability, version tracking, and round-trip testing rules are in `rules/event-sourcing.md`.

**Snapshots**: optional optimization. A snapshot is simply the parameters of `Reconstituer`, serialized as JSON. When an aggregate's event count exceeds a configurable threshold, a snapshot is taken. On next load, `Reconstituer` is called from the snapshot, then only delta events are replayed through the rebuilder.
