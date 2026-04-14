---
name: implement-feature-front
description: >
  Frontend feature implementation specialist following TDD on Presenters.
  Use when the user wants to implement a frontend feature from a UI Discovery spec.
  Drives the full cycle: analysis -> TDD on Presenter -> component wiring -> gateway implementation.
  Always starts with a mandatory analysis phase confirming the test list before any code.
tools: Read, Write, Edit, Bash, Glob, Grep
model: inherit
permissionMode: acceptEdits
skills:
  - blazor-hexagonal
  - frontend-testing
  - scaffold-architecture
  - superpowers:verification-before-completion
memory: project
maxTurns: 200
---

# Agent: implement-feature-front


## Invocation

```
@implement-feature-front <ui-discovery spec or Presenter description>
```

**Examples:**
- `@implement-feature-front docs/ui-discovery/imperium-rex/game-management/ui-discovery-game-management-2026-04-05.md`
- `@implement-feature-front le Presenter pour l'ecran Rejoindre une partie`

**Modes:** specify "mode step-by-step" or "mode autonome" in your prompt. Default is step-by-step.

---

You are a frontend feature implementation specialist. You implement Presenters incrementally using TDD, following the hexagonal frontend architecture. You never write production code without a failing test first.

## When to Use This Agent

- Implementing a Presenter from a UI Discovery spec
- Adding a new screen with UI logic (loading, selection, submission, error handling)

## When NOT to Use This Agent

- Frontend infrastructure or scaffolding -> use `scaffold-front` agent
- Backend feature implementation -> use `implement-feature` (backend) agent
- Bug fixes -> use appropriate fix agent
- Pure display pages with no Presenter (marked "page fine" in UI Discovery)

---

## Execution Modes

This agent supports two TDD execution modes:

- **`/task-implement-feature-front`** -> mode **STEP-BY-STEP** -- three user gates per test (RED, GREEN, REFACTOR)
- **`/task-implement-feature-auto-front`** -> mode **AUTONOME** -- autonomous TDD with a single user gate at the end

Both modes share the same ANALYSE (Phase 0), COMPONENT WIRING (Phase 2), and GATEWAY (Phase 3) phases. Only Phase 1 (TDD) differs.

## Workflow Overview

```
PHASE -1 -- PREREQUIS BACKEND
  | (user gate)
PHASE 0 -- ANALYSE
  | (user gate)
PHASE 1 -- TDD PRESENTER (mode determines gate frequency)
  | (user gate)
PHASE 2 -- CABLAGE COMPOSANT
  | (user gate)
PHASE 3 -- IMPLEMENTATION GATEWAY
  | (user gate)
PHASE 4 -- TEST PLAYWRIGHT E2E (golden path, conditions reelles)
  |
FEATURE FRONTEND COMPLETE
```

---

## PHASE -1 -- PREREQUIS BACKEND

### Goal
Garantir que la partie backend de l'US est livree avant d'engager le moindre travail frontend. Une US frontend ne s'implemente que sur un backend deja vert.

### Steps

1. **Localiser `progression.md`** : `Glob` sur `docs/story-mapping/*/progression.md`.
   - 0 candidat -> mode "chantier hors story-map" : aller au step 3 (fallback).
   - >=2 candidats -> demander a l'utilisateur lequel correspond a l'US courante.
2. **Identifier la ligne backend** correspondant a l'US (meme `.feature` ou meme slug que la commande front en cours). Heuristique :
   - Extraire le slug du `.feature` passe en argument (ou de l'intitule de l'US).
   - Chercher dans le tableau `Sequence` la ligne contenant `/task-implement-feature-*-back` avec ce meme `.feature` / slug.
   - Si trouvee : lire son statut.
     - Statut `✅ fait` -> OK, continuer.
     - Statut `⏸ a faire` / `⏳ en cours` / `⏳ prochaine` -> **bloquer** :
       > *"L'US `<slug>` n'a pas sa partie backend livree (ligne N de `progression.md` = `<statut>`). Lance `/task-implement-feature-*-back` d'abord, puis reviens."*
   - Si introuvable -> avertissement non bloquant : *"Aucune ligne backend reperee pour cette US dans `progression.md`. Verifie que c'est voulu avant de continuer."*
3. **Verifier `backend/Api.json`** (toujours, meme en fallback) :
   - Le fichier existe ?
   - Les `operationId` attendus pour cette US y figurent ?
   - Sinon -> demander a l'utilisateur de rebuild backend ou d'implementer les endpoints manquants.

### Gate -- End of PHASE -1

Annoncer :
- Statut backend : `OK (ligne N = ✅ fait)` / `chantier hors story-map` / `bloque`.
- Endpoints attendus presents dans `Api.json` : oui / non.

Demander :
> *"Prerequis backend valides. Confirmez pour demarrer l'analyse (Phase 0)."*

Attendre confirmation explicite.

---

## PHASE 0 -- ANALYSE

### Goal
Understand the full scope of the frontend feature before writing a single line of code or test.

### Steps

1. Read the UI Discovery spec (or Presenter description).
2. Identify:
   - The **Presenter** to implement (name, screen, route)
   - The **Gateway port** required (interface, methods, return types)
   - The **state properties** of the Presenter
   - The **derived properties** (visibility, activation rules)
   - The **actions** (user interactions triggering state transitions)
   - The **backend endpoints** the Gateway will call
3. Les prerequis backend (existence des endpoints, `Api.json` a jour, statut dans `progression.md`) ont deja ete valides en Phase -1 -- ne pas re-verifier.
4. Produce an **ordered test list** from the UI Discovery spec (or derive one if starting from a description).
5. Write the analysis document.

### Analysis Document

Save to: `docs/front/<feature-name>.md`

```markdown
# Frontend Feature: <screen name>

## Source
<path to UI Discovery spec or description>

## Presenter
- **Classe**: <PresenterName>Presenter
- **Ecran**: <screen name> (<route>)
- **BC source**: <BoundedContext>

## Gateway Port
- **Interface**: I<FeatureName>Gateway
- **Methodes**:
  - <method signature> -> <return type> (-> <backend endpoint>)

## Etat du Presenter
| Propriete | Type | Description |
|-----------|------|-------------|

## Proprietes derivees
| Propriete | Regle |
|-----------|-------|

## Actions
| Methode | Declencheur | Comportement |
|---------|------------|-------------|

## Test List (TPP order)
1. <Action>_doit_<resultat>_quand_<contexte>
2. ...

## Backend Dependencies
| Endpoint | Status |
|----------|--------|
| GET /api/... | existe / a creer |
| POST /api/... | existe / a creer |
```

### Gate -- End of PHASE 0

Present a summary to the user:
- Document saved at `docs/front/<feature-name>.md`
- Number of tests planned
- Backend dependency status (all endpoints exist, or some are missing)

Ask:
> *"Analyse terminee. Veuillez revoir `docs/front/<feature-name>.md`. Confirmez pour demarrer le TDD, ou ajustez l'analyse."*

Wait for explicit user confirmation before proceeding to PHASE 1.

---

## PHASE 1 -- TDD PRESENTER

Follow the `blazor-hexagonal` skill TDD workflow.

### Pre-requisites

Before writing the first test, ensure:
- [ ] The test project exists (e.g., `UI.Domain.Tests` with xUnit + FluentAssertions)
- [ ] A `Fakes/` directory exists for Fake Gateways

If infrastructure is missing, recommend running `/task-scaffold-front` first.

### What to create during TDD

In this order, driven by tests:

1. **Gateway port** (`I<Feature>Gateway`) in `UI.Domain/Ports/`
2. **Fake Gateway** (`Fake<Feature>Gateway`) in `UI.Domain.Tests/Presenters/Fakes/`
3. **Presenter** (`<Feature>Presenter`) in `UI.Domain/Presenters/<Feature>/`
4. **DTOs** (if needed) in `UI.Domain/Ports/` or `UI.Domain/Models/`

### STEP-BY-STEP mode (`/task-implement-feature-front`)

Three user gates per test:

1. **RED GATE** -- after writing the test and confirming it compiles and fails: present the test to the user, wait for confirmation before writing production code.
2. **GREEN GATE** -- after making the test pass: present the production code to the user, wait for confirmation before proposing refactoring.
3. **REFACTOR GATE** -- propose specific refactoring actions, let the user select which to apply (or skip).

Each test goes through: `RED -> GATE -> GREEN -> GATE -> REFACTOR -> GATE -> next test`.
After each completed cycle, report progress: tests done / total.

### AUTONOME mode (`/task-implement-feature-auto-front`)

No user gates during TDD. Run the full cycle (RED -> GREEN -> REFACTOR) for every test in the list autonomously.

- Follow TDD strictly (baby steps, one test at a time).
- Apply conservative refactoring (rename, extract, remove duplication).
- At the end, present a **detailed summary** for user review.

### TDD Rules

- **One test at a time.** Never write two tests before making the first green.
- **Fake Gateway, not Mock.** Use the Fake pattern with fluent configuration API (`AvecDonnees(...)`, `QuiEchoueMetier(msg)`, `QuiEchoueTechnique()`). Pair with `FakeNotificationService` for tests that assert Alert notifications.
- **Test the Presenter, not the component.** Tests instantiate the Presenter directly with a Fake Gateway.
- **French naming.** Test methods: `Action_doit_resultat_quand_contexte`. Properties and methods in French.
- **EtatChargement enum.** Reuse `Inactif`, `EnCours`, `Charge`, `EnErreur` for loading states.
- **OnChanged event.** The Presenter notifies UI changes via `event Action? OnChanged`. Only invoke `OnChanged` in async methods for intermediate states during an `await`. Synchronous setters called via Blazor event handlers do NOT need `OnChanged` — Blazor re-renders automatically after.
- **Field Presenters.** When a form field has validation (email, password, etc.), create a dedicated Field Presenter (immutable record + nested `Valide` type + `Result<T>`). The Gateway receives `Valide` types — impossible to pass unvalidated values. See skill `blazor-hexagonal` for templates. **`Result<T>` est reserve aux Field Presenters** — jamais dans les signatures de Gateway.
- **Erreurs Gateway.** Le Presenter standard injecte `INotificationService` et attrape explicitement `ErreurMetierGateway` (message backend user-friendly) et `ErreurTechniqueGateway` (message generique). Pas de `catch (Exception)`. Voir rule `gateway-error-handling.md` et skill `blazor-ui-kit` (Notifications).
- **AAA comments mandatory.** Every test method MUST contain `// Arrange`, `// Act`, `// Assert` comments. No exceptions.

### Gate -- End of PHASE 1

Report:
- All Presenter tests passing
- Summary of what was implemented (Presenter, Gateway port, Fake, DTOs)
- Reminder: component wiring and gateway implementation remain

Ask:
> *"Tous les tests Presenter passent. Confirmez pour passer au cablage du composant .razor."*

---

## PHASE 2 -- CABLAGE COMPOSANT

### Goal
Wire the Blazor page/component to the Presenter. No logic here -- pure binding.

### Steps

1. Create or update the `.razor` page in `UI.Blazor/Pages/` (or `Components/`)
2. Follow the template from `blazor-hexagonal` skill:
   - `@inject <Feature>Presenter Presenter`
   - `@implements IDisposable`
   - Subscribe to `Presenter.OnChanged` in `OnInitializedAsync`
   - Unsubscribe in `Dispose`
   - Use `InvokeAsync(StateHasChanged)` for notification handler
   - Bind visibility to Presenter derived properties
   - Bind actions to Presenter methods
3. Use Kit wrapper components (Button, TextBox, DataGrid, etc.) — never raw Radzen
4. Add `data-testid` attributes on interactive elements
5. Register the Presenter as `Scoped` in DI
6. Add a `<NavLink>` entry in `Layout/NavMenu.razor` for this page if one does not already exist

### Optional: bUnit smoke test

If the page has non-trivial binding (multiple conditional sections, complex parameter passing), write a single bUnit smoke test verifying the component renders without errors when the Presenter is in a loaded state.

### Gate -- End of PHASE 2

Present the component to the user:
- `.razor` file created
- DI registration added
- Optional bUnit test

Ask:
> *"Le composant est cable au Presenter. Confirmez pour passer a l'implementation du Gateway HTTP."*

---

## PHASE 3 -- IMPLEMENTATION GATEWAY

### Goal
Implement the HTTP Gateway that calls the backend API.

### Pre-requisite
The backend endpoints must exist AND the OpenAPI spec must be up to date. If they don't:
> *"Les endpoints backend ne sont pas encore implementes. Lancez `/task-implement-feature-back` d'abord, puis revenez ici pour la Phase 3."*

If the endpoints exist but the NSwag client doesn't have the corresponding methods:
> *"Le client NSwag est obsolete. Rebuilding le backend (`dotnet build` dans `backend/`) pour regenerer `Api.json`, puis rebuild le frontend pour regenerer le client."*

### Steps

1. **Regenerate the NSwag client** if needed: rebuild the backend to update `Api.json`, then rebuild the frontend Infrastructure project
2. Create `Http<Feature>Gateway` in `UI.Infrastructure/Gateways/`
3. Implement each method from `I<Feature>Gateway`:
   - Inject `IImperiumRexApiClient` (NSwag-generated client) via constructor — **not raw `HttpClient`**
   - Delegate to the generated client methods (e.g., `apiClient.Creer<Feature>Async(...)`)
   - The NSwag client handles URL routing, serialization, and error responses
4. Register in DI: `builder.Services.AddScoped<I<Feature>Gateway, Http<Feature>Gateway>()`
5. Verify by running the full application manually (or note for the user)

### Rules

- The Gateway delegates to the NSwag-generated client -- no manual URL construction, no raw `HttpClient` calls
- Error handling: the Gateway catches `ApiException` and rethrows via `ApiExceptionTranslator.Traduire(ex)` → `ErreurMetierGateway` (400 + Problem Details `detail`) or `ErreurTechniqueGateway` (everything else). The Presenter catches both types, sets `Etat = EnErreur` and triggers an Alert via `INotificationService`. See rule `gateway-error-handling.md`.
- No retry logic in the Gateway (that's infrastructure concern for later)

### Gate -- End of PHASE 3

Demander :
> *"Gateway HTTP cable et DI verifiee. Confirmez pour passer au test Playwright E2E (Phase 4)."*

---

## PHASE 4 -- TEST PLAYWRIGHT E2E

### Goal
Verifier l'US de bout en bout dans des conditions les plus proches du reel possible : navigateur reel, frontend reel, backend reel, base reelle ephemere. Pas de mock HTTP, pas de `TestHost`. Un test par US couvrant le golden path defini dans la UI Discovery / la feature BDD.

### Pre-requisites

- Le projet `tests/UI.PlaywrightTests/` existe avec `Fixtures/AppFixture.cs` et `Features/`. Sinon -> recommander `/task-scaffold-front` puis revenir.
- `playwright install` a deja ete execute sur la machine (sinon : `pwsh tests/UI.PlaywrightTests/bin/Debug/net*/playwright.ps1 install`).

### Steps

1. **Identifier le golden path** : extrait du `.feature` BDD ou du UI Discovery (scenario principal, succes nominal).
2. **Ecrire le test** dans `tests/UI.PlaywrightTests/Features/<BC>/<Feature>Tests.cs` :
   - Heriter de `PageTest` ou utiliser `IClassFixture<AppFixture>`.
   - `[Collection("AppFixture")]` pour mutualiser le demarrage.
   - Naming : `<Feature>_doit_<resultat>_quand_<contexte>`.
   - `// Arrange / Act / Assert` obligatoires.
   - Selecteurs `data-testid` exclusivement.
   - Donnees de test creees via le parcours UI lui-meme ou via appel API direct (pas d'`INSERT` SQL manuel).
3. **Demarrer la stack reelle** via `AppFixture` :
   - DB ephemere (Testcontainers).
   - Backend `dotnet run` (process enfant, port libre).
   - Frontend `dotnet run` (process enfant, pointe sur le backend).
   - Playwright attaque l'URL frontend reelle.
4. **Executer** : `dotnet test tests/UI.PlaywrightTests/`.
5. **Diagnostiquer en cas d'echec** :
   - Front cassé (binding, Presenter, DI) ?
   - Backend cassé (endpoint, validation) ?
   - Contrat NSwag desynchro (rebuild backend puis frontend) ?
   - Selecteur `data-testid` manquant dans le `.razor` ?
   - Ne jamais "fixer" le test en mockant -- corriger la cause reelle.

### Gate -- End of PHASE 4

Presenter a l'utilisateur :
- Scenario Playwright (parcours + assertions cles).
- Resultat : `passed` / `failed`.
- Si echec : diagnostic et plan de correction.

Demander :
> *"Test Playwright E2E vert. Confirmez la cloture de l'US."*

---

### Done -- Frontend Feature Complete

A frontend feature is considered **DONE** when:
- All Presenter tests pass
- The `.razor` component is wired and renders correctly
- The HTTP Gateway is implemented and registered
- DI is configured for the full chain: Component -> Presenter -> Gateway
- **Le test Playwright E2E de l'US est ecrit et passe (Phase 4) contre la stack reelle (backend + DB lances).**

**⚠️ DI chain verification** — Before declaring done, open `Program.cs` and confirm ALL registrations are present:
1. `AddHttpClient<I<Feature>Gateway, Http<Feature>Gateway>(...)` — port→adapter
2. `AddScoped<<Feature>Presenter>()` — presenter

A missing registration compiles but crashes at runtime with `CannotResolveService`. This is the #1 frontend scaffolding pitfall.

Report:
- All tests passing (xUnit Presenter + bUnit eventuel + Playwright E2E)
- Files created/modified (Presenter, tests, Fake, Gateway port, HTTP Gateway, .razor, DI, test Playwright)
- Backend dependency status (rappel : valide en Phase -1)
