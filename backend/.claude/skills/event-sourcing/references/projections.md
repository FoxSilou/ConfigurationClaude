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

## Domain Event Handler interface

Projections implement strongly-typed `IDomainEventHandler<TEvent>` — one handler per event type. No casting, no type-checking, no `EventTypes` property.

```csharp
// Shared.Write.Domain/Abstractions/IDomainEventHandler.cs
public interface IDomainEventHandler<in TEvent> where TEvent : IDomainEvent
{
    Task HandleAsync(TEvent @event, CancellationToken ct = default);
}
```

## Domain Event Bus

The bus dispatches domain events to all registered handlers. It is a port defined in Shared.Write.Domain, with its MediatR adapter in Shared.Write.Infrastructure.

```csharp
// Shared.Write.Domain/Abstractions/IDomainEventBus.cs
public interface IDomainEventBus
{
    Task PublierAsync(IReadOnlyCollection<IDomainEvent> events, CancellationToken ct = default);
}
```

The `MediatRDomainEventBus` adapter wraps each domain event in a `DomainEventNotification<TEvent>` (an `INotification`) and publishes it via MediatR. A `DomainEventNotificationHandler<TEvent>` bridges `IDomainEventHandler<TEvent>` to `INotificationHandler<DomainEventNotification<TEvent>>`.

This follows the same pattern as `ICommandBus` → `MediatRCommandBus` → `CommandRequest<T>` → `CommandRequestHandler<T>`.

## Inline projection example

```csharp
// Read/Infrastructure/Projections/PartieCreeProjection.cs
internal sealed class PartieCreeProjection(ReadDbContext readDb)
    : IDomainEventHandler<PartieCree>
{
    public async Task HandleAsync(PartieCree @event, CancellationToken ct = default)
    {
        readDb.Parties.Add(new PartieReadModel
        {
            Id = @event.PartieId.Valeur,
            Nom = @event.Nom.Valeur,
            Statut = "EnAttente",
            NombreDeJoueurs = 0,
            CreeLe = @event.OccurredOn
        });

        await readDb.SaveChangesAsync(ct);
    }
}

// Read/Infrastructure/Projections/JoueurRejointProjection.cs
internal sealed class JoueurRejointProjection(ReadDbContext readDb)
    : IDomainEventHandler<JoueurRejoint>
{
    public async Task HandleAsync(JoueurRejoint @event, CancellationToken ct = default)
    {
        var partie = await readDb.Parties.FindAsync([@event.PartieId.Valeur], ct);
        if (partie is not null)
            partie.NombreDeJoueurs++;

        await readDb.SaveChangesAsync(ct);
    }
}
```

Each handler is a single class responsible for one event type. This follows SRP and provides compile-time type safety — no casts, no switch statements.

## Side-effect projection example (email, notifications)

Projections are not limited to materializing read models. They can also trigger **side-effects** like sending emails or notifications. The pattern is the same — `IDomainEventHandler<TEvent>` — but the handler calls an application port instead of writing to `ReadDbContext`.

```csharp
// Write/Infrastructure/Projections/UtilisateurInscritEmailProjection.cs
internal sealed class UtilisateurInscritEmailProjection(
    IEmailSender emailSender,
    ILogger<UtilisateurInscritEmailProjection> logger)
    : IDomainEventHandler<UtilisateurInscrit>
{
    public async Task HandleAsync(UtilisateurInscrit @event, CancellationToken ct = default)
    {
        try
        {
            await emailSender.EnvoyerEmailDeConfirmationAsync(
                @event.Email, @event.TokenDeConfirmation, ct);
        }
        catch (Exception ex)
        {
            logger.LogError(ex,
                "Échec de l'envoi de l'email de confirmation pour {UserId}",
                @event.UtilisateurId.Valeur);
        }
    }
}
```

Key differences from read-model projections:
- Lives in **Write Infrastructure** (not Read) since it's a side-effect of the write operation
- **Catches exceptions** — a failed email must not roll back the registration
- Calls an **application port** (`IEmailSender`) instead of writing to `ReadDbContext`
- The port uses **Value Objects** in its signature, not primitives

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

## Wiring into the event store

For inline projections, the `IDomainEventBus` is called right after `AppendToStreamAsync` succeeds, in the same scope. The repository uses the bus port:

```csharp
internal sealed class EventSourcedPartieRepository(
    IEventStore eventStore,
    IDomainEventBus domainEventBus) : IPartieRepository
{
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
        var expectedVersion = partie.Version - uncommitted.Count;

        await eventStore.AppendToStreamAsync(streamKey, uncommitted, expectedVersion, ct);
        await domainEventBus.PublierAsync(uncommitted, ct);

        partie.ClearDomainEvents();
    }

    private static StreamKey ToStreamKey(PartieId id) => new("Partie", id.Valeur);
}
```

The repository depends on `IDomainEventBus` (a domain port), not on any concrete dispatcher or MediatR type.

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
                var publisher = scope.ServiceProvider.GetRequiredService<IDomainEventBus>();
                var eventStoreDb = scope.ServiceProvider.GetRequiredService<WriteDbContext>();
                var readDb = scope.ServiceProvider.GetRequiredService<ReadDbContext>();
                var serializer = scope.ServiceProvider.GetRequiredService<EventSerializer>();
                var mapper = scope.ServiceProvider.GetRequiredService<IEventPayloadMapper>();

                // Load checkpoint
                var checkpoint = await readDb.ProjectionCheckpoints
                    .FirstOrDefaultAsync(c => c.ProjectionName == "Global", stoppingToken)
                    ?? new ProjectionCheckpoint { ProjectionName = "Global", LastProcessedEventId = 0 };

                // Fetch new events
                var newEvents = await eventStoreDb.Events
                    .Where(e => e.Id > checkpoint.LastProcessedEventId)
                    .OrderBy(e => e.Id)
                    .Take(BatchSize)
                    .ToListAsync(stoppingToken);

                if (newEvents.Count == 0)
                {
                    await Task.Delay(PollingInterval, stoppingToken);
                    continue;
                }

                // Deserialize and dispatch through the bus
                var domainEvents = newEvents
                    .Select(e => serializer.Deserialize(e.EventType, e.Payload))
                    .OfType<IDomainEvent>()
                    .ToList();

                await publisher.PublierAsync(domainEvents, stoppingToken);

                // Update checkpoint
                checkpoint.LastProcessedEventId = newEvents.Last().Id;
                checkpoint.UpdatedAt = DateTimeOffset.UtcNow;

                if (readDb.Entry(checkpoint).State == EntityState.Detached)
                    readDb.ProjectionCheckpoints.Add(checkpoint);

                await readDb.SaveChangesAsync(stoppingToken);
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

## Idempotency

Projections **must be idempotent** — applying the same event twice should produce the same result. This is critical because:
- Async projections might process the same event on retry after a failure
- Rebuilding replays all events from scratch
- The bus might (in edge cases) deliver duplicates

Strategies for idempotency:
- **Upsert** instead of insert (use the aggregate Id as the primary key)
- **Check-before-write** for increment operations
- Store the last processed event Id per read model row and skip if already applied

## Integration with existing Read stack

Projections write to the same `ReadDbContext` that query handlers read from. The existing pattern is preserved:

```
Events → IDomainEventBus → IDomainEventHandler<T> → ReadDbContext (writes)
                                                          ↑
Query handler → IQueryHandler → ReadDbContext (reads) → PartieDto
```

Query handlers don't know or care that the data comes from projections rather than from a shared database with the write side. They query `ReadDbContext` and return DTOs exactly as before.

## DI Registration

```csharp
// In the composition root (Api/Program.cs)
// Auto-discovers all IDomainEventHandler<T> implementations in the given assemblies
// and registers both the handler and its MediatR notification adapter
services.AddDomainEventHandlers(typeof(ReadInfraMarkerType).Assembly);

// For async projections
services.AddHostedService<AsyncProjectionWorker>();
```

The `AddDomainEventHandlers` method (defined in `Shared.Write.Infrastructure`) scans assemblies for `IDomainEventHandler<T>` implementations and registers:
1. `IDomainEventHandler<TEvent>` → concrete handler (Scoped) — **one registration per handler implementation**
2. `INotificationHandler<DomainEventNotification<TEvent>>` → `DomainEventNotificationHandler<TEvent>` (Transient) — **one registration per event type** (deduplicated via `HashSet<Type>`)
3. `IDomainEventBus` → `MediatRDomainEventBus` (Scoped)

> ⚠️ **Piège** : `DomainEventNotificationHandler<TEvent>` doit être enregistré **une seule fois par type d'événement**, pas une fois par handler. Si plusieurs handlers existent pour le même événement (ex: `PartieCreeProjection` côté Read ET `PartieCreeIdentityProjection` côté Write), un enregistrement dupliqué provoque l'appel de chaque handler N fois (une fois par `DomainEventNotificationHandler` enregistré), ce qui casse les projections qui font Add + SaveChanges (EF Core tracking conflict). `AddDomainEventHandlers` gère cette déduplication automatiquement.

## Naming conventions

| Element | Convention | Example |
|---|---|---|
| Projection class | Event name + `Projection` | `PartieCreeProjection`, `JoueurRejointProjection` |
| Read model | Aggregate name + `ReadModel` | `PartieReadModel` |
| Checkpoint table | `ProjectionCheckpoints` | Shared across all projections |
| Domain event bus | `IDomainEventBus` / `MediatRDomainEventBus` | Port in Shared.Write.Domain, adapter in Shared.Write.Infrastructure |
| Worker | `AsyncProjectionWorker` | One per bounded context |
