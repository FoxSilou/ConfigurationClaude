---
name: scaffold-architecture
description: >
  Use when scaffolding frontend infrastructure, wiring new feature areas,
  or setting up hexagonal frontend structure (Presenters, Gateways, UI Kit wrappers,
  project dependency graph, testing harness).
user-invocable: false
---

# Skill: Scaffold Architecture — Frontend Infrastructure Rules

These rules are NON-NEGOTIABLE when writing frontend infrastructure code.

---

## Hexagonal Frontend — Presenter / Coquille de rendu

The frontend follows a **hexagonal architecture** adapted to Blazor. See skill `blazor-hexagonal` for full templates.

```
UI.Domain (C# pur, 0 dependance Blazor)
├── Presenters/         -> Intelligence UI : etats, transitions, proprietes derivees
└── Ports/              -> Interfaces des dependances (IXxxGateway)

UI.Infrastructure
└── Gateways/           -> Implementations HTTP des ports

UI.Blazor
├── Pages/              -> Pages routable, coquille de rendu
├── Components/
│   ├── Kit/            -> Wrappers Radzen (seul endroit avec @using Radzen)
│   └── Shared/         -> Composants metier reutilisables (utilisent les Kit)
└── Layout/
```

La fleche de dependance va toujours vers le Domain : **Blazor -> Domain <- Infrastructure**.

---

## Presenter Rules

- **Le Presenter porte toute l'intelligence UI.** Le `.razor` ne fait que binder.
- **Le Presenter est C# pur** — aucun `using Microsoft.AspNetCore.Components`.
- **Les tests ciblent le Presenter, jamais le composant** — via Fakes configurables des Gateways.
- **Pas de logique conditionnelle non triviale dans le `.razor`** — si `@if` combine plus d'un booleen, c'est une propriete derivee du Presenter.
- **Toujours `InvokeAsync(StateHasChanged)`** — jamais `StateHasChanged()` directement.
- **Toujours `IDisposable` + desabonnement `OnChanged`** dans le composant.
- **Le Presenter est Scoped dans le DI** — ni Singleton (partage inter-utilisateurs) ni Transient (perte d'etat).
- **`OnChanged` uniquement dans les methodes async** — pour signaler un etat intermediaire pendant un `await`. Les setters synchrones appeles via event handlers Blazor n'en ont pas besoin (Blazor re-rend automatiquement apres).
- **Field Presenters pour les champs avec validation** — record immutable + type `Valide` imbrique + `Result<T>`. Voir skill `blazor-hexagonal` pour les templates.
- **INotificationService enregistre Scoped** dans la composition root + `Notifications.razor` (wrapper Radzen) monte une fois dans `MainLayout`. Tous les Presenters standards injectent le port pour remonter erreurs / succes a l'utilisateur. Voir rule `gateway-error-handling.md` et skill `blazor-ui-kit` (section Notifications).
- **Exceptions frontend typees** — `ErreurMetierGateway` et `ErreurTechniqueGateway` dans `UI.Domain/Exceptions/`. Helper `ApiExceptionTranslator` dans `UI.Infrastructure/Gateways/` traduit les `ApiException` NSwag en exceptions typees. Voir rule `gateway-error-handling.md`.

---

## Encapsulation des Composants UI Tiers

Les composants de bibliotheques UI tierces (Radzen, MudBlazor, etc.) ne sont **JAMAIS** utilises directement dans les pages ou composants metier. Voir skill `blazor-ui-kit` pour les templates.

- **Noms directs sans prefixe** : `DataGrid`, `Dialog`, `Button`, `TextBox`, `DropDown`, `[Projet]DialogService`
- **`@using Radzen` uniquement dans `Components/Kit/`** — jamais dans une page metier
- **N'exposer que les Parameter utilises** — pas de passthrough generique
- **Nommer en francais** avec le vocabulaire metier quand pertinent (`Colonnes`, `Source`, `EnChargement`)
- **Centraliser les valeurs par defaut** dans le wrapper (taille de page, format de date, densite)
- **Toujours capturer les attributs HTML non declares** via `[Parameter(CaptureUnmatchedValues = true)]` et `@attributes="AttributsSupplementaires"` sur l'element racine — permet le passthrough de `data-testid`, `id`, `aria-*`

---

## Gateway Ports

Les signatures des ports (Gateways) utilisent des DTOs immuables (`record` ou `record struct`), pas des types `HttpResponseMessage` ou `JsonElement`.

- Service interfaces : `I[Feature]Gateway` — decrivent **quoi** (fonctionnel)
- Service implementations : `Http[Feature]Gateway` — decrivent **comment** (HTTP)
- Enregistrement via `AddHttpClient<IXxxGateway, HttpXxxGateway>()`
- Pas de logique metier dans les services — ce sont des clients API purs

---

## Testing Strategy

- **bUnit / xUnit** est le defaut pour les tests de Presenters — logique, etat, proprietes derivees.
- **Playwright** est reserve aux bugs reportes via l'UI ou le chemin d'interaction est lui-meme en cause.
- **`data-testid`** pour tous les selecteurs de test — jamais de classes CSS ou contenu textuel.
- **Fakes et Stubs uniquement** — pas de Mocks (meme philosophie que le backend).
- Les tests Presenter vivent dans `UI.Domain.Tests/` — **pas de dependance Blazor** dans ce projet.
- Voir skill `frontend-testing` pour les templates de tests.
