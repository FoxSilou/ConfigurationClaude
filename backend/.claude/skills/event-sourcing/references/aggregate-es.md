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

The state rebuilder is the only new concept. It is a pure Infrastructure class that knows how to replay event payloads into aggregate state. It bridges the gap between the event store (which stores payloads) and `Reconstituer` (which needs state parameters).

### Fold payloads into a primitive state accumulator, then Reconstituer

The rebuilder receives `IStoredEventPayload` objects — payload records that already contain only primitives. A lightweight state class accumulates changes. Once all payloads are replayed, the accumulated primitives are converted to Value Objects via `Reconstituer` with **full validation**, and passed to the aggregate's `Reconstituer`.

```csharp
// Infrastructure/EventStore/StateRebuilders/PartieStateRebuilder.cs
internal sealed class PartieStateRebuilder : IStateRebuilder<Partie, PartieId>
{
    public Partie Rebuild(PartieId id, IReadOnlyCollection<IStoredEventPayload> payloads)
    {
        var state = new PartieState();

        foreach (var payload in payloads)
        {
            switch (payload)
            {
                case PartieCreePayload e:
                    state.Id = e.PartieId;               // already a Guid
                    state.Nom = e.Nom;                   // already a string
                    state.Statut = "EnAttente";
                    break;

                case JoueurRejointPayload e:
                    state.Joueurs.Add(e.JoueurId);       // already a Guid
                    break;

                case JoueurPartiPayload e:
                    state.Joueurs.Remove(e.JoueurId);
                    break;

                case PartieDemarreePayload:
                    state.Statut = "EnCours";
                    break;

                case PartieTermineePayload:
                    state.Statut = "Terminee";
                    break;
            }
        }

        // VOs created via Reconstituer — full validation
        return Partie.Reconstituer(
            PartieId.Reconstituer(state.Id),
            NomDePartie.Reconstituer(state.Nom),
            StatutPartie.Reconstituer(state.Statut),
            state.Joueurs.Select(JoueurId.Reconstituer));
    }

    // Primitive accumulator — private, throwaway, pure Infrastructure
    private sealed class PartieState
    {
        public Guid Id { get; set; }
        public string Nom { get; set; } = default!;
        public string Statut { get; set; } = default!;
        public List<Guid> Joueurs { get; } = [];
    }
}
```

The state class is a throwaway accumulator — it lives as a private nested class inside the rebuilder. It uses only primitives, never Value Objects. Since payloads already contain primitives, no `.Valeur` extraction is needed in the fold. The conversion to domain types happens only at the final step, via `Reconstituer` on each VO with full validation.

## IStateRebuilder interface

```csharp
// Shared.Write.Infrastructure/EventStore/IStateRebuilder.cs
public interface IStateRebuilder<TAggregate, TId>
    where TAggregate : AggregateRoot<TId>
    where TId : notnull
{
    TAggregate Rebuild(TId id, IReadOnlyCollection<IStoredEventPayload> payloads);
}
```

## Event-sourced repository — uses the rebuilder

```csharp
// Infrastructure/Persistence/EventSourcedPartieRepository.cs
internal sealed class EventSourcedPartieRepository(
    IEventStore eventStore,
    IStoredEventReader eventReader,
    PartieStateRebuilder rebuilder,
    IDomainEventBus domainEventBus) : IPartieRepository
{
    private readonly Dictionary<StreamKey, int> _versions = new();

    public async Task<Partie?> ObtenirParIdAsync(PartieId id, CancellationToken ct = default)
    {
        var streamKey = ToStreamKey(id);

        // Try snapshot first
        var fromVersion = 0;
        Partie? baseAggregate = null;
        var snapshot = await eventStore.LoadSnapshotAsync(streamKey, ct);
        if (snapshot is not null)
        {
            baseAggregate = ((PartieSnapshot)snapshot.State).ToAggregate();
            fromVersion = snapshot.Version + 1;
            _versions[streamKey] = snapshot.Version;
        }

        var payloads = await eventReader.ReadPayloadsAsync(streamKey, fromVersion, ct);

        if (payloads.Count == 0 && baseAggregate is null) return null;
        if (payloads.Count == 0) return baseAggregate;

        var aggregate = rebuilder.Rebuild(id, payloads);

        _versions[streamKey] = fromVersion + payloads.Count - 1;
        return aggregate;
    }

    public async Task AjouterAsync(Partie partie, CancellationToken ct = default)
    {
        var streamKey = ToStreamKey(partie.Id);
        var uncommitted = partie.DomainEvents.ToList();

        await eventStore.AppendToStreamAsync(streamKey, uncommitted, -1, ct);

        await domainEventBus.PublierAsync(uncommitted, ct);

        partie.ClearDomainEvents();
    }

    public async Task MettreAJourAsync(Partie partie, CancellationToken ct = default)
    {
        var streamKey = ToStreamKey(partie.Id);
        var uncommitted = partie.DomainEvents.ToList();
        var expectedVersion = _versions.GetValueOrDefault(streamKey, -1);

        await eventStore.AppendToStreamAsync(streamKey, uncommitted, expectedVersion, ct);
        _versions[streamKey] = expectedVersion + uncommitted.Count;

        await domainEventBus.PublierAsync(uncommitted, ct);

        partie.ClearDomainEvents();
    }

    private static StreamKey ToStreamKey(PartieId id) => new("Partie", id.Valeur);
}
```

Note: The repository uses `IStoredEventReader` for reads (returns `IStoredEventPayload`) and `IEventStore` for writes (accepts `IDomainEvent`). The `IEventStore.AppendToStreamAsync` maps domain events to payloads internally via `IEventPayloadMapper`.

### Version tracking without polluting the aggregate

The aggregate does not carry a `Version` property — optimistic concurrency is managed by the repository. The repository is registered as `Scoped`, so it tracks loaded versions in a dictionary keyed by `StreamKey`. This works naturally with the existing DI lifetime.

## Snapshots

Snapshots are the set of parameters needed by `Reconstituer`, serialized as JSON. Like payloads, snapshot classes use **primitives only** — no Value Objects, no custom JSON converters needed.

```csharp
// Infrastructure/EventStore/Snapshots/PartieSnapshot.cs
internal sealed class PartieSnapshot
{
    public required Guid Id { get; init; }
    public required string Nom { get; init; }
    public required string Statut { get; init; }
    public required List<Guid> Joueurs { get; init; }

    public Partie ToAggregate()
        => Partie.Reconstituer(
            PartieId.Reconstituer(Id),
            NomDePartie.Reconstituer(Nom),
            StatutPartie.Reconstituer(Statut),
            Joueurs.Select(JoueurId.Reconstituer));

    public static PartieSnapshot FromAggregate(Partie partie)
        => new()
        {
            Id = partie.Id.Valeur,
            Nom = partie.Nom.Valeur,
            Statut = partie.Statut.Valeur,
            Joueurs = partie.Joueurs.Select(j => j.Valeur).ToList()
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
- When business rules evolve in a breaking way (e.g., max length reduced), **event upcasters** are needed to transform historical events before replay. This is an explicit Infrastructure cost — the alternative (relaxing VO validation) would silently produce invalid aggregates.

## Testing

Aggregate tests are identical to state-based. The rebuilder gets its own tests, with the **round-trip test** being the most important. This test validates the full pipeline: domain events → payload mapper → payloads → state rebuilder → aggregate:

```csharp
[Fact]
public void Rebuild_round_trip_devrait_etre_coherent()
{
    var id = PartieId.Nouveau();
    var partie = Partie.Creer(id, NomDePartie.Creer("Test"), _maintenant);
    partie.RejoindrePartie(JoueurId.Nouveau(), _maintenant);
    partie.RejoindrePartie(JoueurId.Nouveau(), _maintenant);
    partie.Demarrer(_maintenant);

    var payloads = partie.DomainEvents
        .Select(_mapper.ToPayload)
        .ToList();
    var rebuilt = _rebuilder.Rebuild(id, payloads);

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
