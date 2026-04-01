---
description: "Entity pattern — private constructor, business/persistence factories, typed Ids"
globs: ["**/Domain/**/*.cs", "**/Entities/**/*.cs", "**/Aggregates/**/*.cs"]
---

# Rule: Entity Pattern

## Structure

```csharp
public sealed class <EntityName>
{
    // Private constructor — validates ALL invariants
    private <EntityName>(<TypedId> id, <ValueObject> prop1, ...)
    {
        // ⚠️ ALL invariants are validated HERE, in the constructor
        ArgumentNullException.ThrowIfNull(prop1);
        // Additional domain validation...

        Id = id;
        Prop1 = prop1;
    }

    // Properties — private setters
    public <TypedId> Id { get; private set; }
    public <ValueObject> Prop1 { get; private set; }

    // --- Business factory methods (public) ---
    // Factory methods do NOT validate — they delegate to the private constructor
    public static <EntityName> <BusinessName>(<Parameters>)
    {
        var entity = new <EntityName>(id, prop1, ...);
        // entity.RaiseDomainEvent(new <Event>(...)); // if aggregate root
        return entity;
    }

    // --- Persistence factory method (internal) ---
    // Uses the SAME private constructor — invariants are always enforced
    internal static <EntityName> Reconstituer(<Parameters>)
    {
        return new <EntityName>(id, prop1, ...);
    }

    // --- Behavior methods ---
}
```

## Rules

- **No public constructor** — always use static factory methods.
- **⚠️ INVARIANTS IN THE PRIVATE CONSTRUCTOR** — The private constructor is the **single place** where all invariants are validated. Factory methods (`Creer`, `Reconstituer`) call this constructor. This guarantees that an entity can never exist in an invalid state, whether created for business use or reconstituted from persistence.
- **Business factory methods** are public, named after the ubiquitous language in French (e.g., `Creer`, `Inscrire`, `Demarrer`). They delegate to the private constructor and may add domain events.
- **Persistence factory method** is `internal`, named `Reconstituer(...)`, used exclusively by Infrastructure to rebuild entities from stored primitives. It also calls the private constructor — no bypass of invariants.
- Expose `Reconstituer` to Infrastructure via `InternalsVisibleTo` in the Domain `.csproj`:
  ```xml
  <ItemGroup>
    <AssemblyAttribute Include="System.Runtime.CompilerServices.InternalsVisibleTo">
      <_Parameter1>Infrastructure</_Parameter1>
    </AssemblyAttribute>
  </ItemGroup>
  ```
- All properties have **private setters**.
- **Typed Id**: each entity has a dedicated Id type (e.g., `PartieId`) — never a raw `Guid`.
- **First Class Collections**: collections are never exposed as `List<T>`. Always encapsulate in a dedicated Value Object or expose as `IReadOnlyCollection<T>`.
- **`DateTimeOffset` only**: never use `DateTime`. Always use `DateTimeOffset` for any temporal value.
- **No system clock in the Domain**: the Domain layer must never call `DateTimeOffset.UtcNow`, `DateTime.UtcNow`, `DateTime.Now`, or any system clock directly. The current time is always provided as a parameter (`DateTimeOffset maintenant`) from the Application layer via `TimeProvider`. This ensures full testability.

## Typed Id

Each entity has its own Id type encapsulating a `Guid`:

```csharp
public readonly record struct PartieId(Guid Valeur)
{
    public static PartieId Nouveau() => new(Guid.NewGuid());
    public static PartieId Reconstituer(Guid valeur) => new(valeur);
}
```

## First Class Collection Example

```csharp
public sealed class Joueurs
{
    private readonly List<Joueur> _joueurs = new();

    public IReadOnlyCollection<Joueur> Tous => _joueurs.AsReadOnly();

    public void Ajouter(Joueur joueur)
    {
        if (_joueurs.Any(j => j.Id == joueur.Id))
            throw new DomainException("Ce joueur est déjà inscrit.");
        _joueurs.Add(joueur);
    }
}
```

## Full Example

```csharp
public sealed class Partie
{
    // ⚠️ Invariants validated HERE
    private Partie(PartieId id, NomDePartie nom)
    {
        ArgumentNullException.ThrowIfNull(nom);
        Id = id;
        Nom = nom;
    }

    public PartieId Id { get; private set; }
    public NomDePartie Nom { get; private set; }

    // Business factory — delegates to private constructor
    public static Partie Creer(PartieId id, NomDePartie nom)
    {
        return new Partie(id, nom);
    }

    // Persistence factory — same constructor, same invariants
    internal static Partie Reconstituer(PartieId id, NomDePartie nom)
    {
        return new Partie(id, nom);
    }
}
```

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Business factory | French verb | `Creer`, `Inscrire`, `Demarrer` |
| Persistence factory | Always `Reconstituer` | `Reconstituer(...)` |
| Typed Id | Entity name + `Id` | `PartieId`, `JoueurId` |
| Id factory (new) | `Nouveau()` | `PartieId.Nouveau()` |
| Id factory (from primitive) | `Reconstituer(Guid)` | `PartieId.Reconstituer(guid)` |


---
