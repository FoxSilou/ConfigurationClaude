---
name: frontend-testing
description: >
  Frontend testing conventions for Blazor/MAUI (bUnit + Playwright).
  Use when writing, reviewing, or discussing frontend tests.
  Covers: bUnit component testing, Playwright E2E for UI-reported bugs,
  decision rule for bUnit vs Playwright, service injection with Stubs,
  event handling tests, and data-testid selector conventions.
user-invocable: false
---

# Skill: Frontend Testing (Blazor / MAUI)

## Stack

- **bUnit** — component testing for Blazor (logic, state, rendering)
- **Playwright for .NET** — E2E UI testing for user-reported bugs on critical paths
- **xUnit + FluentAssertions** — same conventions as backend tests

---

## Philosophy

- **bUnit** is the default for frontend bugs — it tests component behavior without a browser.
- **Playwright** is reserved for bugs explicitly reported through the UI where the interaction path itself is part of the bug (click sequence, navigation, visual state).
- Never use Playwright when bUnit can reproduce the bug — bUnit is faster, more stable, and easier to debug.

---

## Decision Rule: bUnit vs Playwright

| Situation | Tool |
|---|---|
| Bug in component logic, state, or data binding | bUnit |
| Bug in a service injected into a component | bUnit |
| Bug triggered by a specific user interaction sequence | Playwright |
| Bug visible only in a rendered browser (CSS, JS interop) | Playwright |
| Bug in navigation or routing | Playwright |
| Bug that requires a running backend | Playwright (or mock via bUnit) |

---

## bUnit — Test Structure

### Setup

```csharp
public class PartieCardTests : TestContext
{
    [Fact]
    public void PartieCard_doit_afficher_le_nom_quand_la_partie_est_chargee()
    {
        // Arrange
        var partie = new PartieDto(Guid.NewGuid(), "Championnat de France");

        // Act
        var cut = RenderComponent<PartieCard>(parameters => parameters
            .Add(p => p.Partie, partie));

        // Assert
        cut.Find("h2").TextContent.Should().Be("Championnat de France");
    }
}
```

### Rules

- Test class inherits `TestContext` from bUnit.
- Naming follows the same convention as backend: `<Component>_doit_<result>_quand_<context>`
- Arrange: prepare parameters and services.
- Act: `RenderComponent<T>` or `FindComponent<T>`.
- Assert: use `cut.Find()`, `cut.FindAll()`, `cut.Instance` with FluentAssertions.
- Never assert on raw HTML strings — use semantic selectors (`h2`, `[data-testid="..."]`).

### Injecting Services

```csharp
[Fact]
public void PartieList_doit_afficher_les_parties_quand_le_service_retourne_des_donnees()
{
    // Arrange
    var stubService = new StubPartieService(new[]
    {
        new PartieDto(Guid.NewGuid(), "Partie A"),
        new PartieDto(Guid.NewGuid(), "Partie B")
    });
    Services.AddSingleton<IPartieService>(stubService);

    // Act
    var cut = RenderComponent<PartieList>();

    // Assert
    cut.FindAll("li").Should().HaveCount(2);
}
```

- Use Stubs for services (same philosophy as backend — no Mocks).
- Register stubs via `Services.AddSingleton<T>()` before rendering.

### Event Handling

```csharp
[Fact]
public void PartieForm_doit_appeler_onSubmit_quand_le_formulaire_est_soumis()
{
    // Arrange
    PartieDto? submitted = null;
    var cut = RenderComponent<PartieForm>(parameters => parameters
        .Add(p => p.OnSubmit, (PartieDto p) => submitted = p));

    // Act
    cut.Find("input[name='nom']").Change("Nouveau tournoi");
    cut.Find("button[type='submit']").Click();

    // Assert
    submitted.Should().NotBeNull();
    submitted!.Nom.Should().Be("Nouveau tournoi");
}
```

---

## Playwright — Test Structure

Playwright tests are reserved for user-reported UI bugs where the interaction path matters.

### Setup

```csharp
[Collection("Playwright")]
public class PartieCreationTests : PageTest
{
    [Fact]
    public async Task CreerPartie_doit_afficher_la_partie_dans_la_liste_apres_creation()
    {
        // Arrange
        await Page.GotoAsync("http://localhost:5000/parties");

        // Act
        await Page.ClickAsync("button[data-testid='creer-partie']");
        await Page.FillAsync("input[name='nom']", "Championnat de France");
        await Page.ClickAsync("button[type='submit']");

        // Assert
        await Expect(Page.Locator("text=Championnat de France")).ToBeVisibleAsync();
    }
}
```

### Rules

- Naming: same convention — `<Feature>_doit_<result>_quand_<context>`
- Always use `data-testid` attributes for selectors — never CSS classes or text content for actions.
- Assert via `Expect(...).ToBeVisibleAsync()` or `ToHaveTextAsync()` — not raw DOM queries.
- Playwright tests require the application to be running — configure base URL via `playwright.config.json`.
- Playwright tests live in a dedicated project: `tests/Frontend.PlaywrightTests/`.

---

## Test File Structure

```
tests/
├── Frontend.bUnitTests/
│   ├── Components/
│   │   └── PartieCardTests.cs
│   └── Pages/
│       └── PartieListTests.cs
└── Frontend.PlaywrightTests/
    └── Bugs/
        └── <BugShortDescription>Tests.cs     ← bug reproduction tests
```

---

## What NOT to Test

- Visual styling (colors, spacing) — not reliable across environments
- Third-party component internals (Syncfusion, MudBlazor…)
- Browser-specific behavior — use `data-testid` and semantic assertions instead
