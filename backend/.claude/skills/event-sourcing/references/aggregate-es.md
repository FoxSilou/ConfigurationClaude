# Event-Sourced Aggregates — Domain-pure approach

## Core principle

The aggregate does not know it is event-sourced. It follows the exact same pattern as a state-based aggregate: `AggregateRoot<TId>`, `RaiseDomainEvent`, `Reconstituer`, invariants in the private constructor. The event sourcing mechanics (replaying events to rebuild state) live entirely in Infrastructure via a **state rebuilder**.

This means:
- The same aggregate class works with EF Core persistence OR event sourcing — only the repository adapter changes.
- No `Apply`/`When` methods in the domain.
- No `EventSourcedAggregate<TId>` base class.
- `Reconstituer` keeps all its parameters, exactly like the state-based pattern.
- Domain events are raised via `RaiseDomainEvent` as always — they happen to also be the events stored in the event store.

## The aggregate — unchanged from state-based

```csharp
// Domain/Aggregates/Partie.cs — IDENTICAL whether persisted via EF Core or Event Sourcing
public sealed class Partie : AggregateRoot<PartieId>
{
    private readonly List<JoueurId> _joueurs = [];

    private Partie(PartieId id, NomDePartie nom, StatutPartie statut)
    {
        ArgumentNullException.ThrowIfNull(nom);
        Id = id;
        Nom = nom;
        Statut = statut;
    }

    public NomDePartie Nom { get; private set; }
    public StatutPartie Statut { get; private set; }
    public IReadOnlyCollection<JoueurId> Joueurs => _joueurs.AsReadOnly();

    // ─── Business factory ───
    public static Partie Creer(PartieId id, NomDePartie nom, DateTimeOffset maintenant)
    {
        var partie = new Partie(id, nom, StatutPartie.EnAttente);
        partie.RaiseDomainEvent(PartieCree.Creer(id, nom, maintenant));
        return partie;
    }

    // ─── Business behavior ───
    public void RejoindrePartie(JoueurId joueurId, DateTimeOffset maintenant)
    {
        if (Statut != StatutPartie.EnAttente)
            throw new DomainException("Impossible de rejoindre une partie qui n'est pas en attente.");
        if (_joueurs.Contains(joueurId))
            throw new DomainException("Ce joueur a deja rejoint la partie.");

        _joueurs.Add(joueurId);
        RaiseDomainEvent(JoueurRejoint.Creer(Id, joueurId, maintenant));
    }

    public void Demarrer(DateTimeOffset maintenant)
    {
        if (Statut != StatutPartie.EnAttente)
            throw new DomainException("La partie ne peut etre demarree que depuis le statut en attente.");
        if (_joueurs.Count < 2)
            throw new DomainException("Il faut au moins 2 joueurs pour demarrer.");

        Statut = StatutPartie.EnCours;
        RaiseDomainEvent(PartieDemarree.Creer(Id, maintenant));
    }

    // ─── Persistence factory — same as state-based ───
    internal static Partie Reconstituer(
        PartieId id,
        NomDePartie nom,
        StatutPartie statut,
        IEnumerable<JoueurId> joueurs)
    {
        var partie = new Partie(id, nom, statut);
        partie._joueurs.AddRange(joueurs);
        return partie;
    }
}
```

Notice: the aggregate mutates its own state directly (`_joueurs.Add`, `Statut = ...`) AND raises a domain event. This is the standard state-based pattern. The domain event is a notification of what happened — it also serves as the source of truth for persistence when using Event Sourcing.

## Domain events — unchanged

```csharp
public sealed record PartieCree(
    PartieId PartieId,
    NomDePartie Nom,
    DateTimeOffset OccurredOn) : IDomainEvent
{
    public static PartieCree Creer(PartieId id, NomDePartie nom, DateTimeOffset maintenant)
        => new(id, nom, maintenant);
}
```

Same pattern as always: `sealed record`, `IDomainEvent`, `Creer` factory, `maintenant` parameter.

## Repository interface — unchanged

```csharp
public interface IPartieRepository
{
    Task<Partie?> ObtenirParIdAsync(PartieId id, CancellationToken ct = default);
    Task AjouterAsync(Partie partie, CancellationToken ct = default);
    Task MettreAJourAsync(Partie partie, CancellationToken ct = default);
}
```

## The state rebuilder — Infrastructure only

The state rebuilder is the only new concept. It is a pure Infrastructure class that knows how to replay events into aggregate state. It bridges the gap between the event store (which stores events) and `Reconstituer` (which needs state parameters).

### Fold into a state record, then Reconstituer

A lightweight state record accumulates changes from events. Once all events are replayed, it passes the accumulated state to `Reconstituer`.

```csharp
// Infrastructure/EventStore/StateRebuilders/PartieStateRebuilder.cs
internal sealed class PartieStateRebuilder : IStateRebuilder<Partie, PartieId>
{
    public Partie Rebuild(PartieId id, IReadOnlyCollection<IDomainEvent> events)
    {
        var state = new PartieState();

        foreach (var @event in events)
        {
            switch (@event)
            {
                case PartieCree e:
                    state.Id = e.PartieId;
                    state.Nom = e.Nom;
                    state.Statut = StatutPartie.EnAttente;
                    break;

                case JoueurRejoint e:
                    state.Joueurs.Add(e.JoueurId);
                    break;

                case JoueurParti e:
                    state.Joueurs.Remove(e.JoueurId);
                    break;

                case PartieDemarree:
                    state.Statut = StatutPartie.EnCours;
                    break;

                case PartieTerminee:
                    state.Statut = StatutPartie.Terminee;
                    break;
            }
        }

        return Partie.Reconstituer(state.Id, state.Nom, state.Statut, state.Joueurs);
    }

    // Mutable state accumulator — internal to Infrastructure, never exposed
    private sealed class PartieState
    {
        public PartieId Id { get; set; }
        public NomDePartie Nom { get; set; } = default!;
        public StatutPartie Statut { get; set; } = default!;
        public List<JoueurId> Joueurs { get; } = [];
    }
}
```

The state record is a throwaway accumulator — it lives as a private nested class inside the rebuilder. It uses mutable properties because it is Infrastructure plumbing, not domain code. The only output is a properly reconstituted aggregate via `Reconstituer`.

## IStateRebuilder interface

```csharp
// SharedKernel.Infrastructure/EventStore/IStateRebuilder.cs
public interface IStateRebuilder<TAggregate, TId>
    where TAggregate : AggregateRoot<TId>
    where TId : notnull
{
    TAggregate Rebuild(TId id, IReadOnlyCollection<IDomainEvent> events);
}
```

## Event-sourced repository — uses the rebuilder

```csharp
// Infrastructure/Persistence/EventSourcedPartieRepository.cs
internal sealed class EventSourcedPartieRepository(
    IEventStore eventStore,
    PartieStateRebuilder rebuilder,
    ProjectionDispatcher? projectionDispatcher = null) : IPartieRepository
{
    private readonly Dictionary<string, int> _versions = new();

    public async Task<Partie?> ObtenirParIdAsync(PartieId id, CancellationToken ct = default)
    {
        var streamId = ToStreamId(id);

        // Try snapshot first
        var fromVersion = 0;
        Partie? baseAggregate = null;
        var snapshot = await eventStore.LoadSnapshotAsync(streamId, ct);
        if (snapshot is not null)
        {
            baseAggregate = ((PartieSnapshot)snapshot.State).ToAggregate();
            fromVersion = snapshot.Version + 1;
            _versions[streamId] = snapshot.Version;
        }

        var events = await eventStore.ReadStreamAsync(streamId, fromVersion, ct);

        if (events.Count == 0 && baseAggregate is null) return null;
        if (events.Count == 0) return baseAggregate;

        // Rebuild: if we have a snapshot base, we need to replay only the delta events.
        // If no snapshot, replay all events from scratch.
        var aggregate = events.Count > 0
            ? rebuilder.Rebuild(id, baseAggregate is null
                ? events
                : CombineSnapshotAndDelta(baseAggregate, events))
            : baseAggregate!;

        _versions[streamId] = fromVersion + events.Count - 1;
        return aggregate;
    }

    public async Task AjouterAsync(Partie partie, CancellationToken ct = default)
    {
        var streamId = ToStreamId(partie.Id);
        var uncommitted = partie.DomainEvents.ToList();

        await eventStore.AppendToStreamAsync(streamId, uncommitted, -1, ct);

        if (projectionDispatcher is not null)
            await projectionDispatcher.DispatchAsync(uncommitted, ct);

        partie.ClearDomainEvents();
    }

    public async Task MettreAJourAsync(Partie partie, CancellationToken ct = default)
    {
        var streamId = ToStreamId(partie.Id);
        var uncommitted = partie.DomainEvents.ToList();
        var expectedVersion = _versions.GetValueOrDefault(streamId, -1);

        await eventStore.AppendToStreamAsync(streamId, uncommitted, expectedVersion, ct);
        _versions[streamId] = expectedVersion + uncommitted.Count;

        if (projectionDispatcher is not null)
            await projectionDispatcher.DispatchAsync(uncommitted, ct);

        partie.ClearDomainEvents();
    }

    private static string ToStreamId(PartieId id) => $"Partie-{id.Valeur}";

    private static IReadOnlyCollection<IDomainEvent> CombineSnapshotAndDelta(
        Partie snapshotBase,
        IReadOnlyCollection<IDomainEvent> deltaEvents)
    {
        // For simplicity, replay all events including those already in the snapshot.
        // In practice, use fromVersion to only replay delta events via the rebuilder.
        // This is a simplified version — see snapshot section for full implementation.
        return deltaEvents;
    }
}
```

### Version tracking without polluting the aggregate

The aggregate does not carry a `Version` property — optimistic concurrency is managed by the repository. The repository is registered as `Scoped`, so it tracks loaded versions in a dictionary keyed by stream ID. This works naturally with the existing DI lifetime.

## Snapshots

Snapshots are the set of parameters needed by `Reconstituer`, serialized as JSON. The snapshot class mirrors the rebuilder's state record:

```csharp
// Infrastructure/EventStore/Snapshots/PartieSnapshot.cs
internal sealed class PartieSnapshot
{
    public required PartieId Id { get; init; }
    public required NomDePartie Nom { get; init; }
    public required StatutPartie Statut { get; init; }
    public required List<JoueurId> Joueurs { get; init; }

    public Partie ToAggregate()
        => Partie.Reconstituer(Id, Nom, Statut, Joueurs);

    public static PartieSnapshot FromAggregate(Partie partie)
        => new()
        {
            Id = partie.Id,
            Nom = partie.Nom,
            Statut = partie.Statut,
            Joueurs = partie.Joueurs.ToList()
        };
}
```

## Key differences from Pattern 1 (Apply/When in aggregate)

| Aspect | Pattern 1 (Apply/When) | Pattern 2 (State rebuilder) |
|---|---|---|
| Aggregate base class | `EventSourcedAggregate<TId>` | `AggregateRoot<TId>` (unchanged) |
| State mutation | Only through `When` via `Apply` | Direct in business methods (standard) |
| Validation | In business methods before `Apply` | In private constructor (standard) |
| `Reconstituer` | No parameters, empty shell | Full parameters (standard) |
| ES awareness in domain | Yes | No — domain is pure |
| Version tracking | Property on aggregate | Repository field (infra bookkeeping) |
| New infrastructure code | Minimal | One `StateRebuilder` per aggregate |
| Portability | Aggregate tied to ES | Same aggregate works with EF Core or ES |

## Trade-offs

**Benefits:**
- Domain layer is completely agnostic to persistence strategy — swap DI registration, done.
- `Reconstituer` semantics are preserved exactly.
- Testing is simpler — same patterns regardless of persistence strategy.

**Costs:**
- One `StateRebuilder` per aggregate. Follows a mechanical pattern, fully testable in isolation.
- State mutation happens twice conceptually: once in business methods, once in the rebuilder. They must stay in sync. **Mitigate with round-trip integration tests** (create aggregate → capture events → rebuild → assert same observable state).
- Version tracking is slightly less elegant (infra bookkeeping vs a clean `Version` property).

## Testing

Aggregate tests are identical to state-based. The rebuilder gets its own tests, with the **round-trip test** being the most important:

```csharp
[Fact]
public void Rebuild_round_trip_devrait_etre_coherent()
{
    var id = PartieId.Nouveau();
    var partie = Partie.Creer(id, NomDePartie.Creer("Test"), _maintenant);
    partie.RejoindrePartie(JoueurId.Nouveau(), _maintenant);
    partie.RejoindrePartie(JoueurId.Nouveau(), _maintenant);
    partie.Demarrer(_maintenant);

    var events = partie.DomainEvents.ToList();
    var rebuilt = _rebuilder.Rebuild(id, events);

    rebuilt.Nom.Should().Be(partie.Nom);
    rebuilt.Statut.Should().Be(partie.Statut);
    rebuilt.Joueurs.Should().BeEquivalentTo(partie.Joueurs);
}
```

## Migration path: state-based to event-sourced

Since the aggregate does not change, migration is purely an infrastructure task:

1. Create the `EventStore` and `AggregateSnapshots` SQL tables
2. Write the `StateRebuilder` for the aggregate
3. Write the `EventSourcedRepository` implementing the same `IRepository` interface
4. Swap the DI registration from `EfCorePartieRepository` to `EventSourcedPartieRepository`
5. Add projections to feed the Read side (previously, the Read side queried the same DB tables)
6. Migrate existing data: for each aggregate row, emit a creation event to bootstrap the stream

The domain layer is untouched. The Application layer is untouched. Only Infrastructure changes.
