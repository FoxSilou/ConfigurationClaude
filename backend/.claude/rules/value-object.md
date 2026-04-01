---
description: "Value Object pattern — readonly record struct, Creer/Reconstituer factories, no primitive obsession"
globs: ["**/Domain/**/*.cs", "**/ValueObjects/**/*.cs"]
---

# Rule: Value Object Pattern

## Structure

```csharp
public readonly record struct <ValueObjectName>
{
    public <Type> Valeur { get; }

    // ⚠️ ALL invariants are validated in the private constructor
    private <ValueObjectName>(<Type> valeur)
    {
        // Validate invariants HERE
        if (/* invalid */) throw new DomainException("...");
        Valeur = valeur;
    }

    // Business factory method (public) — delegates to constructor
    public static <ValueObjectName> Creer(<Type> valeur) => new(valeur);

    // Persistence factory method (internal) — SAME constructor, SAME invariants
    internal static <ValueObjectName> Reconstituer(<Type> valeur) => new(valeur);
}
```

## Rules

- Always use `readonly record struct` — equality by member is automatic, allocation is avoided.
- **No public constructor** — always use static factory methods.
- **⚠️ INVARIANTS IN THE PRIVATE CONSTRUCTOR** — The private constructor is the **single place** where all invariants are validated. Both `Creer` and `Reconstituer` call the same constructor. A Value Object can **never** exist in an invalid state, even when reconstituted from persistence.
- **Business factory methods** are public, named after the ubiquitous language in French (`Creer`, `Definir`, `Initialiser`…). They delegate to the private constructor.
- **Persistence factory method** is `internal`, named `Reconstituer(...)` — calls the same constructor with invariant validation. Used to reconstitute from stored primitives.
- **No primitive obsession**: never use raw primitives where a concept exists in the domain. This includes enumerations — wrap them in a Value Object rather than exposing a raw `enum`.
- Value Objects are **immutable**: no setters, no mutation methods. Transformations return a new instance.
- The exposed property is named `Valeur` for single-value VOs.
- **`DateTimeOffset` only**: never use `DateTime` in Value Objects. Always `DateTimeOffset`.
- **No system clock in the Domain**: Value Objects must never call `DateTimeOffset.UtcNow`, `DateTime.UtcNow`, `DateTime.Now`, or any system clock directly. The current time is always received as a parameter from the Application layer (via `TimeProvider`). This ensures full testability.

## Encapsulated Enum Example

```csharp
// Raw enum — private or internal, never exposed directly
internal enum StatutPartieEnum { EnAttente, EnCours, Terminee }

// Value Object wrapping the enum
public readonly record struct StatutPartie
{
    private readonly StatutPartieEnum _valeur;

    private StatutPartie(StatutPartieEnum valeur) => _valeur = valeur;

    public static readonly StatutPartie EnAttente = new(StatutPartieEnum.EnAttente);
    public static readonly StatutPartie EnCours   = new(StatutPartieEnum.EnCours);
    public static readonly StatutPartie Terminee  = new(StatutPartieEnum.Terminee);

    internal static StatutPartie Reconstituer(StatutPartieEnum valeur) => new(valeur);

    public bool EstTerminee => _valeur == StatutPartieEnum.Terminee;
}
```

## First Class Collection Example

```csharp
public readonly record struct Tags
{
    private readonly IReadOnlyCollection<Tag> _tags;

    public IReadOnlyCollection<Tag> Tous => _tags;

    private Tags(IReadOnlyCollection<Tag> tags) => _tags = tags;

    public static Tags Creer(IEnumerable<Tag> tags)
    {
        var liste = tags.ToList();
        if (liste.Count == 0) throw new DomainException("Au moins un tag est requis.");
        return new Tags(liste.AsReadOnly());
    }

    internal static Tags Reconstituer(IEnumerable<Tag> tags) => new(tags.ToList().AsReadOnly());
}
```

## Full Example

```csharp
public readonly record struct NomDePartie
{
    public string Valeur { get; }

    // ⚠️ Invariants validated in the constructor
    private NomDePartie(string valeur)
    {
        if (string.IsNullOrWhiteSpace(valeur))
            throw new DomainException("Le nom de la partie ne peut pas être vide.");
        if (valeur.Length > 100)
            throw new DomainException("Le nom de la partie ne peut pas dépasser 100 caractères.");

        Valeur = valeur.Trim();
    }

    // Business factory — delegates to constructor
    public static NomDePartie Creer(string valeur) => new(valeur);

    // Persistence factory — same constructor, same invariants
    internal static NomDePartie Reconstituer(string valeur) => new(valeur);
}
```

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Value Object | French domain noun | `NomDePartie`, `StatutPartie`, `Montant` |
| Business factory | French verb | `Creer`, `Definir` |
| Persistence factory | Always `Reconstituer` | `Reconstituer(string valeur)` |
| Main property | `Valeur` | `NomDePartie.Valeur` |
| Collection property | `Tous` | `Tags.Tous` |
