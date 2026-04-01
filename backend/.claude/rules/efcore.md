---
description: "Entity Framework Core — persistence models, data annotations, ToDomain/FromDomain mapping"
alwaysApply: false
globs: ["**/Infrastructure/**/*.cs", "**/Persistence/**/*.cs"]
---

# Rule: Entity Framework Core

## Core Principle

Prefer **EF Core Data Annotations (attributes)** over Fluent API configurations to keep all mapping information visible at a glance, in one place.

## Persistence Model

Each aggregate has a corresponding `internal sealed` persistence model class carrying all EF Core attributes:

```csharp
[Table("Parties")]
internal sealed class PartieModel
{
    [Key]
    public Guid Id { get; set; }

    [Required]
    [MaxLength(100)]
    public string Nom { get; set; } = string.Empty;

    public Partie ToDomain() => Partie.Reconstituer(
        PartieId.Reconstituer(Id),
        NomDePartie.Reconstituer(Nom)
    );

    public static PartieModel FromDomain(Partie partie) => new()
    {
        Id = partie.Id.Valeur,
        Nom = partie.Nom.Valeur
    };
}
```

## Rules

- Persistence models are `internal sealed` classes — never exposed outside Infrastructure.
- **`ToDomain()` always uses `Reconstituer()`** on entities, value objects, and typed Ids.
- **`FromDomain(...)` extracts `.Valeur`** from Value Objects and Typed Ids to get primitives.
- EF Core attributes are placed **only on persistence models**, never on domain entities or value objects.
- Domain entities never have a `[Key]`, `[Table]`, `[Required]`, or any EF Core attribute.
- **`DateTimeOffset`** for all temporal columns — never `DateTime`.

## Structure

```
Infrastructure/
└── Persistence/
    ├── AppDbContext.cs
    └── Models/
        ├── PartieModel.cs
        └── JoueurModel.cs
```


---
