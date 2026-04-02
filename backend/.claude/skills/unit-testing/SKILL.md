---
name: unit-testing
description: >
  Unit testing conventions for the backend (Classical School / Outside-In).
  Use when writing, reviewing, or discussing unit tests for Commands or Queries.
  Covers: AAA structure, test doubles (Fakes/Stubs only, no Mocks),
  French naming conventions, FluentAssertions patterns, and test file organization.
user-invocable: false
---


# Skill: Unit Testing

## Philosophy

This project follows the **Classical School** (Detroit/Chicago) of unit testing, combined with an **Outside-In** approach through use cases.

### Core Principles

- Test **observable behavior**, never implementation details.
- A test that breaks after an internal refactoring (without changing behavior) is a **bad test**.
- **Unit tests ONLY test Commands** — they are written at the use case boundary (Command handler). Value Objects, Aggregates, and Entities are tested implicitly through the Command handler, never in isolation.
- Real domain collaborators are used inside the hexagon. Only **external ports** (persistence, email, etc.) are replaced by test doubles.
- If something is hard to test, **the design is wrong** — fix the design, not the test.

---

## Test Structure — Arrange / Act / Assert

Every test follows the AAA pattern, with explicit blank-line separation between sections:

```csharp
[Fact]
public async Task Creer_une_partie_quand_les_donnees_sont_valides()
{
    // Arrange
    var repository = new InMemoryPartieRepository();
    var handler = new CreerPartie.Handler(repository);
    var commande = new CreerPartie("Championnat de France");

    // Act
    var id = await handler.HandleAsync(commande);

    // Assert
    var partie = await repository.ObtenirParIdAsync(id);
    partie.Should().NotBeNull();
    partie!.Nom.Valeur.Should().Be("Championnat de France");
}
```

### Rules

- **Arrange**: build all dependencies and inputs. Use real domain objects, Fakes or Stubs for ports.
- **Act**: one single action — call the handler or method under test.
- **Assert**: verify the observable outcome only. Never assert on internal state that is not exposed by the domain.
- Never mix multiple behaviors in a single test. One test = one behavior.

---

## Test Naming Convention

### Class name

```
<CommandOrQuery>Doit
```

The class name includes the use case name followed by `Doit`, reading as the subject of a specification.

### Method name

```
<Expected_result>_quand_<context>
```

The method name completes the sentence started by the class name. It starts with an infinitive verb.

- The name mirrors the ubiquitous language — use French for domain concepts.
- The name must read as a **specification**, not a technical description.
- Avoid technical terms (`handler`, `repository`, `mock`) in the test name.
- When read as `ClassName.MethodName`, it forms a full sentence: `CreerPartieDoit.Retourner_un_id_quand_les_donnees_sont_valides`.

### Examples

```csharp
public sealed class CreerPartieDoit
{
    Retourner_un_id_quand_les_donnees_sont_valides()
    Echouer_quand_le_nom_est_trop_long()
    Echouer_quand_le_nom_est_vide()
}

public sealed class ObtenirPartieDoit
{
    Retourner_la_partie_quand_elle_existe()
    Echouer_quand_la_partie_est_introuvable()
}
```

---

## Test Doubles

Only two types of test doubles are used in this project.

### Naming Convention for Test Doubles

| Type | Prefix | Example |
|---|---|---|
| Fake | `Fake` | `FakeEmailSender` |
| Stub | `Stubbed` | `StubbedHorloge` |
| In-memory repository (Fake) | `InMemory` | `InMemoryUtilisateurRepository` |

### Fake

A working in-memory implementation of a port. Used when the test needs to verify **state after the action** (e.g., something was persisted).

```csharp
internal sealed class InMemoryPartieRepository : IPartieRepository
{
    private readonly Dictionary<PartieId, Partie> _store = new();

    public Task AjouterAsync(Partie partie, CancellationToken ct = default)
    {
        _store[partie.Id] = partie;
        return Task.CompletedTask;
    }

    public Task<Partie?> ObtenirParIdAsync(PartieId id, CancellationToken ct = default)
        => Task.FromResult(_store.GetValueOrDefault(id));
}
```

**When to use**: when you need to assert on what was stored or retrieved.

### Stub

Returns a fixed value for a specific input. Used when the test needs to **control an external response** without caring about storage.

```csharp
internal sealed class StubbedPartieRepository : IPartieRepository
{
    private readonly Partie? _partie;

    public StubbedPartieRepository(Partie? partie = null) => _partie = partie;

    public Task<Partie?> ObtenirParIdAsync(PartieId id, CancellationToken ct = default)
        => Task.FromResult(_partie);

    public Task AjouterAsync(Partie partie, CancellationToken ct = default)
        => Task.CompletedTask;
}
```

**When to use**: when you need to simulate a specific state without persisting anything.

### Never Use Mocks

- Do not use `Mock<T>` (Moq) or `Substitute.For<T>` (NSubstitute) for domain ports.
- Mocks couple tests to implementation details (which methods were called, how many times).
- Fakes and Stubs are explicit, readable, and refactoring-safe.

---

## Assertions — FluentAssertions

Always use FluentAssertions (`.Should()` style). Never use `Assert.Equal` or `Assert.True`.

### Value assertions

```csharp
result.Should().Be(expected);
result.Should().NotBeNull();
result.Should().BeGreaterThan(0);
collection.Should().HaveCount(3);
collection.Should().ContainSingle();
collection.Should().BeEmpty();
```

### Domain Event assertions

```csharp
aggregate.DomainEvents.Should().ContainSingle(e => e is PartieCree);
aggregate.DomainEvents.Should().HaveCount(1);
```

### Exception assertions

```csharp
var act = () => NomDePartie.Creer("");
act.Should().Throw<DomainException>()
   .WithMessage("*vide*");
```

### Result<T> assertions

```csharp
result.IsSuccess.Should().BeTrue();
result.Value.Should().Be(expected);

result.IsSuccess.Should().BeFalse();
result.Error.Should().Contain("nom");
```

### Domain Event assertions

When testing aggregate roots, verify that the correct domain events were raised:

```csharp
// Assert a single event was raised with correct data
var partie = Partie.Creer(id, nom, maintenant);
partie.DomainEvents.Should().ContainSingle()
    .Which.Should().BeOfType<PartieCree>()
    .Which.PartieId.Should().Be(id);

// Assert multiple events
utilisateur.DomainEvents.Should().HaveCount(2);
utilisateur.DomainEvents.Should().ContainSingle(e => e is UtilisateurInscrit);
utilisateur.DomainEvents.Should().ContainSingle(e => e is EmailDeConfirmationEnvoye);

// Assert event content
var evt = partie.DomainEvents.OfType<PartieCree>().Single();
evt.PartieId.Should().Be(id);
evt.Nom.Should().Be(nom);
evt.OccurredOn.Should().Be(maintenant);

// Assert Reconstituer does NOT raise events
var reconstituee = Partie.Reconstituer(id, nom);
reconstituee.DomainEvents.Should().BeEmpty();
```

---

## What NOT to Test in Unit Tests

- **Value Objects, Aggregates, Entities in isolation** — they are tested implicitly through the Command handler. If a VO validation matters, it surfaces when the handler constructs it.
- **Internal domain class methods** not reachable from a use case boundary — if it matters, it surfaces through the handler.
- **Infrastructure adapters** in unit tests — use integration tests with TestContainers instead.
- **Private methods** — if a private method needs testing, extract it into a domain concept.
- **Framework behavior** (EF Core, ASP.NET Core routing) — not your responsibility to test.

---

## Test File Structure

The test project is named `<BC>.UnitTests` (e.g., `Identite.UnitTests`). Test files are **flat at the root** of the project — no subdirectories per Command (no `ValueObjects/`, `Aggregates/`, `Handlers/` folders). Only the `Fakes/` directory is allowed.

```
tests/
└── <BC>.UnitTests/
    ├── InscrireUtilisateurDoit.cs
    ├── ConfirmerEmailDoit.cs
    └── Fakes/
        ├── FakeUtilisateurRepository.cs
        ├── FakePasswordHasher.cs
        └── FakeEmailSender.cs
```

One test file = one Command. All scenarios for that Command live in the same file.


