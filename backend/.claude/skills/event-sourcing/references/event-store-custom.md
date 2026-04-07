# Custom SQL Event Store

## Overview

The event store is a simple append-only persistence layer backed by SQL. **SQL Server is the default** — the schema below uses SQL Server syntax. A PostgreSQL variant is noted where the syntax differs.

This is an Infrastructure concern — the domain never references the event store directly. The domain works with `IPartieRepository`; the `EventSourcedPartieRepository` uses `IEventStore` internally.

## Database schema

### Events table

```sql
CREATE TABLE EventStore (
    Id                  BIGINT IDENTITY(1,1) PRIMARY KEY,  -- Global sequence
    EntityName          NVARCHAR(250)   NOT NULL,           -- Aggregate type, e.g. "Partie"
    EntityId            UNIQUEIDENTIFIER NOT NULL,          -- Aggregate instance ID
    StreamVersion       INT             NOT NULL,           -- Position in stream (0-based)
    EventType           NVARCHAR(500)   NOT NULL,           -- CLR type discriminator
    Payload             NVARCHAR(MAX)   NOT NULL,           -- Serialized event (JSON)
    OccurredOn          DATETIMEOFFSET  NOT NULL,           -- From the domain event
    StoredAt            DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),

    CONSTRAINT UQ_Stream_Version UNIQUE (EntityName, EntityId, StreamVersion)
);

CREATE INDEX IX_EventStore_Stream ON EventStore (EntityName, EntityId);
```

The `UNIQUE (EntityName, EntityId, StreamVersion)` constraint enforces optimistic concurrency — two concurrent writes to the same stream at the same version will cause a conflict.

**PostgreSQL variant**: replace `NVARCHAR` with `TEXT`, `BIGINT IDENTITY` with `BIGSERIAL`, `NVARCHAR(MAX)` with `JSONB` (enables JSON indexing), `UNIQUEIDENTIFIER` with `UUID`, `DATETIMEOFFSET` with `TIMESTAMPTZ`, `SYSDATETIMEOFFSET()` with `NOW()`.

**SQL Server performance tip**: for high-throughput streams, consider adding `WITH (FILLFACTOR = 90)` on the unique constraint index to reduce page splits from frequent sequential inserts.

### Snapshots table

```sql
CREATE TABLE AggregateSnapshots (
    EntityName          NVARCHAR(250)   NOT NULL,
    EntityId            UNIQUEIDENTIFIER NOT NULL,
    StreamVersion       INT             NOT NULL,           -- Version at which snapshot was taken
    SnapshotType        NVARCHAR(500)   NOT NULL,
    Payload             NVARCHAR(MAX)   NOT NULL,
    CreatedAt           DATETIMEOFFSET  NOT NULL DEFAULT SYSDATETIMEOFFSET(),

    CONSTRAINT PK_Snapshots PRIMARY KEY (EntityName, EntityId)  -- One snapshot per stream (latest)
);
```

## Event Store port

```csharp
// Shared.Write.Domain/Abstractions/StreamKey.cs
public sealed record StreamKey(string EntityName, Guid EntityId);

// Shared.Write.Domain/Abstractions/IEventStore.cs
public interface IEventStore
{
    /// <summary>
    /// Appends events to a stream, enforcing optimistic concurrency.
    /// </summary>
    /// <param name="streamKey">Composite stream identifier (EntityName + EntityId)</param>
    /// <param name="events">Events to append</param>
    /// <param name="expectedVersion">
    /// The version the caller expects the stream to be at.
    /// -1 means the stream should not exist yet (creation).
    /// </param>
    /// <exception cref="ConcurrencyException">
    /// Thrown when the stream's current version does not match expectedVersion.
    /// </exception>
    Task AppendToStreamAsync(
        StreamKey streamKey,
        IReadOnlyCollection<IDomainEvent> events,
        int expectedVersion,
        CancellationToken ct = default);

    /// <summary>
    /// Reads all events from a stream, optionally starting from a given version.
    /// </summary>
    Task<IReadOnlyCollection<IDomainEvent>> ReadStreamAsync(
        StreamKey streamKey,
        int fromVersion = 0,
        CancellationToken ct = default);

    /// <summary>
    /// Loads the latest snapshot for a stream, if one exists.
    /// </summary>
    Task<Snapshot?> LoadSnapshotAsync(
        StreamKey streamKey,
        CancellationToken ct = default);

    /// <summary>
    /// Saves a snapshot for a stream, replacing any existing snapshot.
    /// </summary>
    Task SaveSnapshotAsync(
        StreamKey streamKey,
        int version,
        object state,
        CancellationToken ct = default);
}

public sealed record Snapshot(int Version, object State);

// Shared.Write.Infrastructure/Exceptions/ConcurrencyException.cs
// NOT in Shared.Write.Domain (pure domain) — this is an infrastructure concern (store conflict).
// Lives in Shared.Write.Infrastructure.
public class ConcurrencyException(string message)
    : Exception(message);
```

### Where to place infrastructure-shared types: `Shared.Write.Infrastructure`

Some types are shared across bounded contexts but are infrastructure concerns, not domain concepts. Examples: `ConcurrencyException`, `EventSerializer`, `TypedIdConverterFactory`, `IStateRebuilder`, `IEventUpcaster`.

These belong in `Shared.Write.Infrastructure` which references `Shared.Write.Domain` (for `IDomainEvent`, `IEventStore`, `ITypedId<T>`) and can take technical dependencies (System.Text.Json, EF Core abstractions).

```
src/
├── Shared/
│   ├── Write/
│   │   ├── Shared.Write.Domain.csproj           ← Pure C#, zero dependencies
│   │   │   ├── ITypedId.cs
│   │   │   ├── Abstractions/
│   │   │   │   └── IEventStore.cs
│   │   │   └── Exceptions/
│   │   │       └── DomainException.cs
│   │   └── Shared.Write.Infrastructure.csproj   ← Technical, references Shared.Write.Domain
│   ├── Exceptions/
│   │   └── ConcurrencyException.cs
│   ├── EventStore/
│   │   ├── IStateRebuilder.cs
│   │   └── IEventUpcaster.cs
│   ├── Serialization/
│   │   ├── EventSerializer.cs
│   │   ├── TypedIdConverter.cs
│   │   └── TypedIdConverterFactory.cs
│   └── Read/                                     ← Created when needed
└── <BoundedContext>/
    └── Write/
        └── <BC>.Write.Infrastructure.csproj
            ├── EventStore/StateRebuilders/
            │   └── PartieStateRebuilder.cs          ← Concrete, per aggregate
            └── Persistence/
                └── EventSourcedPartieRepository.cs  ← Concrete, uses StateRebuilder
```

## SQL Event Store implementation

```csharp
// Infrastructure/EventStore/SqlEventStore.cs
internal sealed class SqlEventStore(
    WriteDbContext dbContext,
    EventSerializer serializer,
    IEnumerable<IEventUpcaster> upcasters) : IEventStore
{
    public async Task AppendToStreamAsync(
        StreamKey streamKey,
        IReadOnlyCollection<IDomainEvent> events,
        int expectedVersion,
        CancellationToken ct = default)
    {
        // Optimistic concurrency check
        var currentVersion = await dbContext.Events
            .Where(e => e.EntityName == streamKey.EntityName && e.EntityId == streamKey.EntityId)
            .MaxAsync(e => (int?)e.StreamVersion, ct) ?? -1;

        if (currentVersion != expectedVersion)
            throw new ConcurrencyException(
                $"Concurrency conflict on stream '{streamKey.EntityName}/{streamKey.EntityId}' at expected version {expectedVersion}.");

        var version = expectedVersion;
        foreach (var @event in events)
        {
            version++;
            dbContext.Events.Add(new StoredEvent
            {
                EntityName = streamKey.EntityName,
                EntityId = streamKey.EntityId,
                StreamVersion = version,
                EventType = serializer.GetDiscriminator(@event),
                Payload = serializer.Serialize(@event),
                OccurredOn = @event.OccurredOn
            });
        }

        await dbContext.SaveChangesAsync(ct);
    }

    public async Task<IReadOnlyCollection<IDomainEvent>> ReadStreamAsync(
        StreamKey streamKey,
        int fromVersion = 0,
        CancellationToken ct = default)
    {
        var storedEvents = await dbContext.Events
            .Where(e => e.EntityName == streamKey.EntityName && e.EntityId == streamKey.EntityId && e.StreamVersion >= fromVersion)
            .OrderBy(e => e.StreamVersion)
            .ToListAsync(ct);

        return storedEvents
            .Select(e =>
            {
                var payload = ApplyUpcasters(e.EventType, e.StreamVersion, e.Payload);
                return serializer.Deserialize(e.EventType, payload);
            })
            .ToList()
            .AsReadOnly();
    }

    private string ApplyUpcasters(string eventType, int version, string payload)
    {
        foreach (var upcaster in upcasters)
        {
            if (upcaster.CanUpcast(eventType, version))
                payload = upcaster.Upcast(eventType, version, payload);
        }

        return payload;
    }

    public async Task<Snapshot?> LoadSnapshotAsync(
        StreamKey streamKey,
        CancellationToken ct = default)
    {
        var stored = await dbContext.Snapshots
            .FirstOrDefaultAsync(s => s.EntityName == streamKey.EntityName && s.EntityId == streamKey.EntityId, ct);

        if (stored is null) return null;

        var state = serializer.DeserializeSnapshot(stored.SnapshotType, stored.Payload);
        return new Snapshot(stored.StreamVersion, state);
    }

    public async Task SaveSnapshotAsync(
        StreamKey streamKey,
        int version,
        object state,
        CancellationToken ct = default)
    {
        var existing = await dbContext.Snapshots
            .FirstOrDefaultAsync(s => s.EntityName == streamKey.EntityName && s.EntityId == streamKey.EntityId, ct);

        var typeName = state.GetType().AssemblyQualifiedName!;
        var payload = serializer.SerializeSnapshot(state);

        if (existing is not null)
        {
            existing.StreamVersion = version;
            existing.SnapshotType = typeName;
            existing.Payload = payload;
        }
        else
        {
            dbContext.Snapshots.Add(new AggregateSnapshot
            {
                EntityName = streamKey.EntityName,
                EntityId = streamKey.EntityId,
                StreamVersion = version,
                SnapshotType = typeName,
                Payload = payload
            });
        }

        await dbContext.SaveChangesAsync(ct);
    }
}
```

## Persistence models (EF Core)

```csharp
// Infrastructure/EventStore/Models/StoredEvent.cs
[Table("EventStore")]
internal sealed class StoredEvent
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public long Id { get; set; }

    [Required]
    [MaxLength(250)]
    public required string EntityName { get; set; }

    public required Guid EntityId { get; set; }

    public required int StreamVersion { get; set; }

    [Required]
    [MaxLength(500)]
    public required string EventType { get; set; }

    [Required]
    public required string Payload { get; set; }

    public required DateTimeOffset OccurredOn { get; set; }

    public DateTimeOffset StoredAt { get; set; }
}

// Infrastructure/EventStore/Models/AggregateSnapshot.cs
[Table("AggregateSnapshots")]
internal sealed class AggregateSnapshot
{
    [Required]
    [MaxLength(250)]
    public required string EntityName { get; set; }

    public required Guid EntityId { get; set; }

    public required int StreamVersion { get; set; }

    [Required]
    [MaxLength(500)]
    public required string SnapshotType { get; set; }

    [Required]
    public required string Payload { get; set; }

    public DateTimeOffset CreatedAt { get; set; }
}
```

## Event serialization

The serializer maps between `IDomainEvent` instances and their JSON representation. It uses a **discriminator** (the event type name) to know which concrete type to deserialize to.

```csharp
// Infrastructure/EventStore/EventSerializer.cs
internal sealed class EventSerializer
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false,
        Converters =
        {
            new TypedIdConverterFactory(),
            new ValueObjectConverterFactory()
        }
    };

    // Maps discriminator string → CLR type. Populated at startup via assembly scanning.
    private readonly Dictionary<string, Type> _eventTypes;

    public EventSerializer(params Assembly[] assemblies)
    {
        _eventTypes = assemblies
            .SelectMany(a => a.GetTypes())
            .Where(t => t.IsAssignableTo(typeof(IDomainEvent)) && !t.IsAbstract)
            .ToDictionary(t => t.Name, t => t);
    }

    public string GetDiscriminator(IDomainEvent @event) => @event.GetType().Name;

    public string Serialize(IDomainEvent @event)
        => JsonSerializer.Serialize(@event, @event.GetType(), Options);

    public IDomainEvent Deserialize(string discriminator, string payload)
    {
        if (!_eventTypes.TryGetValue(discriminator, out var type))
            throw new InvalidOperationException(
                $"Unknown event type '{discriminator}'. Register it in the event serializer.");

        return (IDomainEvent)JsonSerializer.Deserialize(payload, type, Options)!;
    }

    public string SerializeSnapshot(object state)
        => JsonSerializer.Serialize(state, state.GetType(), Options);

    public object DeserializeSnapshot(string typeName, string payload)
    {
        var type = Type.GetType(typeName)
            ?? throw new InvalidOperationException($"Unknown snapshot type '{typeName}'.");
        return JsonSerializer.Deserialize(payload, type, Options)!;
    }
}
```

### ITypedId interface and JSON converters for Typed Ids

Domain events contain Value Objects and Typed Ids. The serializer needs custom converters so that e.g. `PartieId` serializes as a plain GUID string rather than `{"Valeur": "..."}`.

Rather than using fragile reflection, define a contract in Shared.Write.Domain that all Typed Ids implement:

```csharp
// Shared.Write.Domain/ITypedId.cs
public interface ITypedId<out TPrimitive>
{
    TPrimitive Valeur { get; }
}
```

Each Typed Id implements it:

```csharp
public readonly record struct PartieId(Guid Valeur) : ITypedId<Guid>
{
    public static PartieId Nouveau() => new(Guid.NewGuid());
    public static PartieId Reconstituer(Guid valeur) => new(valeur);
}
```

The generic converter uses the interface — no reflection needed for reading/writing:

```csharp
// Shared.Write.Infrastructure/Serialization/TypedIdConverter.cs
internal sealed class TypedIdConverter<TId> : JsonConverter<TId>
    where TId : struct, ITypedId<Guid>
{
    public override TId Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        var guid = reader.GetGuid();
        // Each typed Id is a readonly record struct with a single Guid constructor parameter
        return (TId)Activator.CreateInstance(typeToConvert, guid)!;
    }

    public override void Write(Utf8JsonWriter writer, TId value, JsonSerializerOptions options)
    {
        writer.WriteStringValue(value.Valeur);
    }
}
```

A factory simplifies registration for all Typed Ids in a given assembly:

```csharp
// Shared.Write.Infrastructure/Serialization/TypedIdConverterFactory.cs
internal sealed class TypedIdConverterFactory : JsonConverterFactory
{
    public override bool CanConvert(Type typeToConvert)
        => typeToConvert.IsValueType
           && typeToConvert.GetInterfaces().Any(i =>
               i.IsGenericType && i.GetGenericTypeDefinition() == typeof(ITypedId<>));

    public override JsonConverter CreateConverter(Type typeToConvert, JsonSerializerOptions options)
    {
        var converterType = typeof(TypedIdConverter<>).MakeGenericType(typeToConvert);
        return (JsonConverter)Activator.CreateInstance(converterType)!;
    }
}
```

Register the factory once in the serializer options — it handles all current and future Typed Ids automatically:

```csharp
private static readonly JsonSerializerOptions Options = new()
{
    PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    WriteIndented = false,
    Converters = { new TypedIdConverterFactory() }
};
```

## Repository pattern

The concrete event-sourced repository uses an `IStateRebuilder` to replay events into aggregate state. There is no generic base class — each repository is a concrete implementation because the StateRebuilder is aggregate-specific.

See `references/aggregate-es.md` for the full repository implementation with:
- Version tracking via scoped dictionary (no version on the aggregate)
- Snapshot integration via `Reconstituer` parameters
- Projection dispatch after event persistence

## DI registration

```csharp
// Infrastructure/DependencyInjection.cs
public static IServiceCollection AddEventSourcing(
    this IServiceCollection services,
    string connectionString,
    params Assembly[] domainAssemblies)
{
    services.AddDbContext<WriteDbContext>(options =>
        options.UseSqlServer(connectionString)); // or UseNpgsql for PostgreSQL

    services.AddSingleton(new EventSerializer(domainAssemblies));
    services.AddScoped<IEventStore, SqlEventStore>();

    return services;
}

// Per bounded context
public static IServiceCollection AddPartieEventSourcing(this IServiceCollection services)
{
    services.AddScoped<IPartieRepository, EventSourcedPartieRepository>();
    return services;
}
```

## WriteDbContext

```csharp
// Infrastructure/EventStore/WriteDbContext.cs
internal sealed class WriteDbContext(DbContextOptions<WriteDbContext> options)
    : DbContext(options)
{
    public DbSet<StoredEvent> Events => Set<StoredEvent>();
    public DbSet<AggregateSnapshot> Snapshots => Set<AggregateSnapshot>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<StoredEvent>(entity =>
        {
            entity.HasIndex(e => new { e.EntityName, e.EntityId });
            entity.HasIndex(e => new { e.EntityName, e.EntityId, e.StreamVersion }).IsUnique();
            entity.Property(e => e.StoredAt).HasDefaultValueSql("SYSDATETIMEOFFSET()");
        });

        modelBuilder.Entity<AggregateSnapshot>(entity =>
        {
            entity.HasKey(e => new { e.EntityName, e.EntityId });
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("SYSDATETIMEOFFSET()");
        });
    }
}
```
