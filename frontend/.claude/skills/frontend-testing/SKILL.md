---
name: frontend-testing
description: >
  Use when writing, reviewing, or discussing frontend tests Blazor/MAUI :
  test bUnit d'un composant ou Presenter, test Playwright E2E pour la livraison
  d'une US (golden path) ou pour reproduire un bug UI, choix bUnit vs Playwright,
  injection de Stubs, sélecteurs data-testid, fixture AppFixture pour stack réelle.
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
- **Playwright est requis pour chaque US livrée** : un test E2E par US couvrant le golden path, exécuté contre la stack réelle (backend démarré + DB éphémère). C'est le critère de clôture d'une US frontend (cf. Phase 4 de `implement-feature-front`).
- **Playwright additionnel** est aussi utilisé pour les bugs UI dont le chemin d'interaction (clic, navigation, état rendu) fait partie du bug.
- Pour les bugs purement logiques d'un Presenter ou composant, rester sur bUnit — plus rapide, plus stable.

---

## Decision Rule: bUnit vs Playwright

| Situation | Tool |
|---|---|
| **Livraison d'une US (golden path)** | **Playwright (obligatoire)** |
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
- Playwright tests live in a dedicated project: `tests/UI.PlaywrightTests/`.

---

## Test Playwright d'US — conditions réelles

Chaque US se clôture par un test Playwright E2E qui rejoue le golden path **dans des conditions les plus proches du réel possible**.

### Règles de réalisme

- **Backend réel démarré** (`dotnet run` du projet WebApi en process enfant) — pas de `WebApplicationFactory`, pas de mock HTTP.
- **DB éphémère réelle** via Testcontainers (Postgres/SQL Server selon la stack backend), ou SQLite fichier temporaire si la stack le supporte. Détruite en tear-down. Pas d'`INSERT` manuel — les données de test sont créées via API ou via le parcours UI lui-même.
- **Frontend réel servi** (`dotnet run` du projet Blazor en process enfant).
- **Navigateur réel** piloté par Playwright via `Page.GotoAsync(<url>)`.
- **Sélecteurs `data-testid` exclusivement** — jamais CSS, classes, ou texte.

### Fixture partagée `AppFixture`

Provisionnée par `/task-scaffold-front` dans `tests/UI.PlaywrightTests/Fixtures/AppFixture.cs`. Elle implémente `IAsyncLifetime` et :

1. démarre la DB (Testcontainers) ;
2. démarre backend (process enfant, port libre, env vars pointant sur la DB) ;
3. démarre frontend (process enfant, env vars pointant sur le backend) ;
4. expose `BaseUrlFront` / `BaseUrlBack` ;
5. tear-down complet (kill processes + dispose container).

Mutualisation entre tests via `[CollectionDefinition("AppFixture")]` + `[Collection("AppFixture")]` sur les classes de test.

### Neutraliser les protections cross-cutting (symétrie E2EFixture / AppFixture)

Le backend expose des protections cross-cutting (rate limiter, lockout Identity, throttling mail, anti-forgery, etc.) qui sont **neutralisées en E2E backend** via `ConfigureAppConfiguration` + `InMemoryCollection` dans `WebApplicationFactory`. `AppFixture` frontend démarre le même backend mais **en sous-processus** (`dotnet run`) : l'`InMemoryCollection` n'est pas disponible. Chaque override backend E2E doit être **répliqué via env vars** dans `envBackend` sous la forme `Section__SousSection__Cle=valeur` (double underscore = séparateur de section pour le provider `EnvironmentVariablesConfigurationProvider`).

**Check obligatoire avant clôture d'une US frontend** :

1. Ouvrir `backend/tests/<*>.E2E.Tests/E2EFixture.cs` → lister les clés de l'`InMemoryCollection`.
2. Ouvrir `frontend/tests/<*>.PlaywrightTests/Fixtures/AppFixture.cs` → vérifier que chaque clé backend est traduite en env var (`Section:Cle` → `Section__Cle`).
3. Toute protection backend non-neutralisée côté front fera échouer le run global dès que le quota est atteint — erreur silencieuse en `--filter` (cf. section suivante).

**Exemples de clés à répliquer systématiquement** : rate limiter (`RateLimiting:Auth:*`, `RateLimiting:Login:*`…), lockout Identity, throttling mail, clés JWT dev si différentes.

### Squelette d'un test d'US

```csharp
[Collection("AppFixture")]
public class InscrireUtilisateur_GoldenPath_Tests : PageTest
{
    private readonly AppFixture _app;

    public InscrireUtilisateur_GoldenPath_Tests(AppFixture app) => _app = app;

    [Fact]
    public async Task InscrireUtilisateur_doit_afficher_confirmation_quand_le_formulaire_est_valide()
    {
        // Arrange
        await Page.GotoAsync($"{_app.BaseUrlFront}/inscription");

        // Act
        await Page.FillAsync("[data-testid='champ-pseudo']", "joueur1");
        await Page.FillAsync("[data-testid='champ-email']", "joueur1@example.com");
        await Page.FillAsync("[data-testid='champ-mdp']", "MotDePasse!1");
        await Page.ClickAsync("[data-testid='bouton-inscrire']");

        // Assert
        await Expect(Page.Locator("[data-testid='confirmation-inscription']")).ToBeVisibleAsync();
    }
}
```

### Run global obligatoire avant clôture

Pendant la rédaction, il est acceptable de filtrer un test individuel pour itérer vite :

```bash
dotnet test tests/UI.PlaywrightTests --filter MonTestSpecifique
```

**Mais la clôture d'une US exige le run global sans filter** :

```bash
dotnet test tests/UI.PlaywrightTests
```

**Pourquoi** : tous les tests Playwright partagent la **même instance `AppFixture`** (backend + frontend + DB démarrés une fois, fenêtre rate limiter partagée, DB non réinitialisée entre tests). Les collisions qui n'apparaissent qu'en suite :

- Quota rate limiter atteint (auth, inscription, login).
- État DB persistant entre tests (email unique, pseudonyme unique).
- Tokens JWT expirés ou collisions de `sub` quand plusieurs tests forgent un JWT.
- Compteurs de lockout / rejeu d'email de confirmation.

Un test vert en `--filter` mais rouge en run global = **trou de conception** (soit dans le test, soit dans la neutralisation des protections cross-cutting — cf. section précédente). À fixer avant de déclarer l'US livrée. **Jamais de clôture sur la foi d'un run filtré.**

---

## Test File Structure

```
tests/
├── UI.bUnitTests/
│   ├── Components/
│   │   └── PartieCardTests.cs
│   └── Pages/
│       └── PartieListTests.cs
└── UI.PlaywrightTests/
    ├── Fixtures/
    │   └── AppFixture.cs                     ← démarre DB + backend + frontend réels
    ├── Features/
    │   └── <BC>/
    │       └── <Feature>Tests.cs             ← golden path par US (livraison)
    └── Bugs/
        └── <BugShortDescription>Tests.cs     ← bug reproduction tests
```

---

## What NOT to Test

- Visual styling (colors, spacing) — not reliable across environments
- Third-party component internals (Syncfusion, MudBlazor…)
- Browser-specific behavior — use `data-testid` and semantic assertions instead
