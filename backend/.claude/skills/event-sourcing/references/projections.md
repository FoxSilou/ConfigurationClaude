# Projections and Read Models

## Overview

In an event-sourced system, the write side stores events — not queryable state. The read side needs **projections**: components that consume events and build read-optimized models (flat tables, denormalized views, search indices).

Projections are the bridge between the event store and the existing Read stack (ReadDbContext, DTOs, query handlers).

## Projection types

### Inline projections (synchronous)

Updated in the **same transaction** as event persistence. The read model is always consistent with the write model. Simple to implement, but couples read and write performance.

Best for: essential read models that must be immediately consistent, low-throughput systems, getting started.

### Async projections

Updated **after** event persistence, via a background worker or message bus. Eventually consistent but decoupled — the read side can be rebuilt independently without affecting write performance.

Best for: high-throughput systems, multiple read models per stream, read models in different databases, projections that are expensive to compute.

**Start with inline projections** unless you have a specific reason for async. You can always switch later — the projection logic itself is identical, only the dispatch mechanism changes.

## Projection interface

```csharp
// SharedKernel/Abstractions/IProjection.cs
public interface IProjection
{
    /// <summary>
    /// Returns the event types this projection is interested in.
    /// Used by the dispatcher to route events efficiently.
    /// </summary>
    IReadOnlyCollection<Type> EventTypes { get; }

    /// <summary>
    /// Projects a single event into the read model.
    /// Must be idempotent — replaying the same event twice produces the same result.
    /// </summary>
    Task ProjectAsync(IDomainEvent @event, CancellationToken ct = default);
}
```

## Inline projection example

```csharp
// Infrastructure/Projections/PartieProjection.cs
internal sealed class PartieProjection(ReadDbContext readDb) : IProjection
{
    public IReadOnlyCollection<Type> EventTypes =>
    [
        typeof(PartieCree),
        typeof(JoueurRejoint),
        typeof(PartieDemarree)
    ];

    public async Task ProjectAsync(IDomainEvent @event, CancellationToken ct = default)
    {
        switch (@event)
        {
            case PartieCree e:
                readDb.Parties.Add(new PartieReadModel
                {
                    Id = e.PartieId.Valeur,
                    Nom = e.Nom.Valeur,
                    Statut = "EnAttente",
                    NombreDeJoueurs = 0,
                    CreeLe = e.OccurredOn
                });
                break;

            case JoueurRejoint e:
                var partieJoueur = await readDb.Parties.FindAsync([e.PartieId.Valeur], ct);
                if (partieJoueur is not null)
                    partieJoueur.NombreDeJoueurs++;
                break;

            case PartieDemarree e:
                var partieDemarree = await readDb.Parties.FindAsync([e.PartieId.Valeur], ct);
                if (partieDemarree is not null)
                    partieDemarree.Statut = "EnCours";
                break;
        }
    }
}
```

## Read model

```csharp
// Read/Infrastructure/ReadModels/PartieReadModel.cs
[Table("PartiesReadModel")]
internal sealed class PartieReadModel
{
    [Key]
    public Guid Id { get; set; }

    [Required]
    [MaxLength(100)]
    public required string Nom { get; set; }

    [Required]
    [MaxLength(50)]
    public required string Statut { get; set; }

    public int NombreDeJoueurs { get; set; }

    public DateTimeOffset CreeLe { get; set; }
}
```

The read model is a flat, denormalized table optimized for queries. It uses primitives (not Value Objects) because it belongs to the Read side.

## Projection dispatcher — inline

The dispatcher hooks into the event persistence pipeline. After events are appended to the store, it routes each event to the appropriate projections.

```csharp
// Infrastructure/Projections/ProjectionDispatcher.cs
internal sealed class ProjectionDispatcher(IEnumerable<IProjection> projections)
{
    private readonly ILookup<Type, IProjection> _projectionsByEventType =
        projections
            .SelectMany(p => p.EventTypes.Select(et => (EventType: et, Projection: p)))
            .ToLookup(x => x.EventType, x => x.Projection);

    public async Task DispatchAsync(
        IReadOnlyCollection<IDomainEvent> events,
        CancellationToken ct = default)
    {
        foreach (var @event in events)
        {
            var eventType = @event.GetType();
            foreach (var projection in _projectionsByEventType[eventType])
            {
                await projection.ProjectAsync(@event, ct);
            }
        }
    }
}
```

### Wiring into the event store

For inline projections, the dispatcher is called right after `AppendToStreamAsync` succeeds, in the same scope. One approach is to wrap it in the repository:

```csharp
internal sealed class EventSourcedPartieRepository(
    IEventStore eventStore,
    ProjectionDispatcher projectionDispatcher) : IPartieRepository
{
    // ... ObtenirParIdAsync unchanged ...

    public async Task AjouterAsync(Partie partie, CancellationToken ct = default)
    {
        var streamId = $"Partie-{partie.Id.Valeur}";
        var uncommitted = partie.DomainEvents.ToList();

        await eventStore.AppendToStreamAsync(streamId, uncommitted, -1, ct);
        await projectionDispatcher.DispatchAsync(uncommitted, ct);

        partie.ClearDomainEvents();
    }

    public async Task MettreAJourAsync(Partie partie, CancellationToken ct = default)
    {
        var streamId = $"Partie-{partie.Id.Valeur}";
        var uncommitted = partie.DomainEvents.ToList();
        var expectedVersion = partie.Version - uncommitted.Count;

        await eventStore.AppendToStreamAsync(streamId, uncommitted, expectedVersion, ct);
        await projectionDispatcher.DispatchAsync(uncommitted, ct);

        partie.ClearDomainEvents();
    }
}
```

An alternative (cleaner, but more complex) is a MediatR pipeline behavior that dispatches projections after persistence — this keeps the repository free from projection concerns.

### Who calls SaveChanges on ReadDbContext?

The projection methods modify EF Core tracked entities but do **not** call `SaveChangesAsync` themselves. This keeps them composable — multiple projections can process the same batch of events, and a single `SaveChangesAsync` persists all changes atomically.

The caller is responsible for saving. In the inline approach, the repository does it after dispatching:

```csharp
await eventStore.AppendToStreamAsync(streamId, uncommitted, expectedVersion, ct);
await projectionDispatcher.DispatchAsync(uncommitted, ct);
await readDb.SaveChangesAsync(ct); // Persists all read model changes in one roundtrip
```

In the async worker approach, the worker calls `SaveChangesAsync` after processing each batch (this is already shown in the worker code below).

## Async projections

For async projections, add a checkpoint to track progress:

```csharp
// Infrastructure/Projections/ProjectionCheckpoint.cs
[Table("ProjectionCheckpoints")]
internal sealed class ProjectionCheckpoint
{
    [Key]
    [MaxLength(250)]
    public required string ProjectionName { get; set; }

    /// <summary>
    /// The global event Id (from EventStore.Id) up to which this projection has been processed.
    /// </summary>
    public long LastProcessedEventId { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }
}
```

### Background worker

```csharp
// Infrastructure/Projections/AsyncProjectionWorker.cs
internal sealed class AsyncProjectionWorker(
    IServiceScopeFactory scopeFactory,
    ILogger<AsyncProjectionWorker> logger) : BackgroundService
{
    private const int BatchSize = 100;
    private static readonly TimeSpan PollingInterval = TimeSpan.FromMilliseconds(500);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                var dbContext = scope.ServiceProvider.GetRequiredService<EventStoreDbContext>();
                var readDb = scope.ServiceProvider.GetRequiredService<ReadDbContext>();
                var serializer = scope.ServiceProvider.GetRequiredService<EventSerializer>();
                var projections = scope.ServiceProvider.GetServices<IProjection>().ToList();
                var dispatcher = new ProjectionDispatcher(projections);

                foreach (var projection in projections)
                {
                    var projectionName = projection.GetType().Name;
                    var checkpoint = await readDb.ProjectionCheckpoints
                        .FirstOrDefaultAsync(c => c.ProjectionName == projectionName, stoppingToken)
                        ?? new ProjectionCheckpoint { ProjectionName = projectionName, LastProcessedEventId = 0 };

                    var newEvents = await dbContext.Events
                        .Where(e => e.Id > checkpoint.LastProcessedEventId)
                        .OrderBy(e => e.Id)
                        .Take(BatchSize)
                        .ToListAsync(stoppingToken);

                    if (newEvents.Count == 0) continue;

                    var domainEvents = newEvents
                        .Where(e => projection.EventTypes.Any(t => t.Name == e.EventType))
                        .Select(e => serializer.Deserialize(e.EventType, e.Payload))
                        .ToList();

                    foreach (var @event in domainEvents)
                        await projection.ProjectAsync(@event, stoppingToken);

                    checkpoint.LastProcessedEventId = newEvents.Last().Id;
                    checkpoint.UpdatedAt = DateTimeOffset.UtcNow;

                    if (readDb.Entry(checkpoint).State == EntityState.Detached)
                        readDb.ProjectionCheckpoints.Add(checkpoint);

                    await readDb.SaveChangesAsync(stoppingToken);
                }
            }
            catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
            {
                logger.LogError(ex, "Error in async projection worker. Retrying in {Interval}.", PollingInterval);
            }

            await Task.Delay(PollingInterval, stoppingToken);
        }
    }
}
```

## Projection rebuild

One of the great benefits of event sourcing: read models can be rebuilt from scratch at any time by replaying all events through the projections.

```csharp
// Infrastructure/Projections/ProjectionRebuilder.cs
internal sealed class ProjectionRebuilder(
    EventStoreDbContext eventStoreDb,
    ReadDbContext readDb,
    EventSerializer serializer)
{
    public async Task RebuildAsync<TProjection>(
        TProjection projection,
        CancellationToken ct = default) where TProjection : IProjection
    {
        // 1. Clear the read model tables this projection owns
        //    (implementation depends on which tables — could be a method on the projection)

        // 2. Reset checkpoint
        var projectionName = typeof(TProjection).Name;
        var checkpoint = await readDb.ProjectionCheckpoints
            .FirstOrDefaultAsync(c => c.ProjectionName == projectionName, ct);

        if (checkpoint is not null)
            checkpoint.LastProcessedEventId = 0;

        // 3. Replay all relevant events
        var relevantTypes = projection.EventTypes.Select(t => t.Name).ToHashSet();

        var events = await eventStoreDb.Events
            .Where(e => relevantTypes.Contains(e.EventType))
            .OrderBy(e => e.Id)
            .ToListAsync(ct);

        foreach (var storedEvent in events)
        {
            var domainEvent = serializer.Deserialize(storedEvent.EventType, storedEvent.Payload);
            await projection.ProjectAsync(domainEvent, ct);
        }

        await readDb.SaveChangesAsync(ct);
    }
}
```

For large event stores, process events in batches to avoid loading everything in memory.

## Idempotency

Projections **must be idempotent** — applying the same event twice should produce the same result. This is critical because:
- Async projections might process the same event on retry after a failure
- Rebuilding replays all events from scratch
- The dispatcher might (in edge cases) deliver duplicates

Strategies for idempotency:
- **Upsert** instead of insert (use the aggregate Id as the primary key)
- **Check-before-write** for increment operations
- Store the last processed event Id per read model row and skip if already applied

## Integration with existing Read stack

Projections write to the same `ReadDbContext` that query handlers read from. The existing pattern is preserved:

```
Events → ProjectionDispatcher → IProjection → ReadDbContext (writes)
                                                    ↑
Query handler → IQueryHandler → ReadDbContext (reads) → PartieDto
```

Query handlers don't know or care that the data comes from projections rather than from a shared database with the write side. They query `ReadDbContext` and return DTOs exactly as before.

## DI Registration

```csharp
// Register projections
services.AddScoped<IProjection, PartieProjection>();
services.AddScoped<IProjection, JoueurProjection>();

// Register dispatcher
services.AddScoped<ProjectionDispatcher>();

// For async projections
services.AddHostedService<AsyncProjectionWorker>();
```

## Naming conventions

| Element | Convention | Example |
|---|---|---|
| Projection class | Aggregate name + `Projection` | `PartieProjection` |
| Read model | Aggregate name + `ReadModel` | `PartieReadModel` |
| Checkpoint table | `ProjectionCheckpoints` | Shared across all projections |
| Dispatcher | `ProjectionDispatcher` | One per bounded context |
| Worker | `AsyncProjectionWorker` | One per bounded context |
