# Rule: Event Sourcing Constraints

## Core Principle — The domain does not know it is event-sourced

How an aggregate is persisted (relational tables, document store, event stream) is an **infrastructure decision**, not a domain decision. The domain raises domain events because they are meaningful business facts — not because they serve as a persistence mechanism.

This project follows the **State Rebuilder** pattern (also known as "external fold"):

- The aggregate uses the standard `AggregateRoot<TId>` base class — **no** `EventSourcedAggregate`, **no** `Apply`/`When`.
- Business methods mutate state directly AND raise domain events, exactly as in state-based aggregates.
- `Reconstituer` keeps all its parameters — identical to the EF Core version.
- A **StateRebuilder** (Infrastructure) replays events through a fold, then calls `Reconstituer` to produce the aggregate.
- Swapping from EF Core to Event Sourcing is a pure DI registration change — domain and application layers are untouched.

## Rules

### Domain purity

- **No ES awareness in the domain** — no `Apply`, `When`, `Mutate`, or any event-replay method on the aggregate.
- **No `EventSourcedAggregate<TId>` base class** — all aggregates use `AggregateRoot<TId>`, regardless of persistence strategy.
- **`Reconstituer` is identical** whether the aggregate is persisted via EF Core or Event Sourcing — same parameters, same signature.
- **The same aggregate class works with both persistence strategies** — only the repository adapter and DI registration change.

### Event immutability

- **Events are immutable once published** — never modify an existing event type's shape.
- To evolve an event's structure, create a new event type (e.g., `PartieCreeV2`) and write an **upcaster** that transforms old events when loading.
- Upcasters are Infrastructure concerns — they live in `Infrastructure/EventStore/`.

### Version tracking

- **Optimistic concurrency uses a version number on the aggregate stream**, managed by the repository (Infrastructure bookkeeping), **not** by the aggregate.
- The aggregate does not carry a `Version` property.
- The repository is registered as `Scoped` and tracks loaded versions in a dictionary keyed by stream ID.

### Round-trip testing

- **Every StateRebuilder must have a round-trip test**: create an aggregate via business methods → capture its events → rebuild from those events → assert the same observable state.
- This catches synchronization drift between business methods and the rebuilder.
- Round-trip tests live alongside other unit tests for the bounded context.

### Naming conventions

| Element | Convention | Example |
|---|---|---|
| Event store classes | English, technical | `SqlEventStore`, `StoredEvent`, `EventStoreDbContext` |
| Event-sourced repository | `EventSourced` + aggregate name | `EventSourcedPartieRepository` |
| State rebuilder | Aggregate name + `StateRebuilder` | `PartieStateRebuilder` |
| Projections | Aggregate name + `Projection` / `ProjectionDispatcher` | `PartieProjection`, `ProjectionDispatcher` |
| Domain events | French past participle (unchanged) | `PartieCree`, `JoueurRejoint` |
| Snapshot class | Aggregate name + `Snapshot` | `PartieSnapshot` |


---
