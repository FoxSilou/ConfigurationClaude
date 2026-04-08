---
name: blazor-hexagonal
description: >
  Architecture hexagonale frontend pour Blazor : Presenters C# purs testables en xUnit,
  séparation stricte entre intelligence UI et rendu.
  Utiliser ce skill chaque fois que l'utilisateur demande de créer un nouveau composant Blazor
  avec de la logique UI, un nouvel écran, un Presenter, un Fake Gateway, ou des tests unitaires
  de comportement UI. Également quand l'utilisateur mentionne TDD frontend Blazor, machine à états UI,
  logique de visibilité, ou veut refactorer un composant .razor existant pour en extraire la logique.
user-invocable: false
---

# Blazor Hexagonal Frontend

Ce skill guide la création de composants Blazor selon une architecture hexagonale frontend :
le Presenter porte toute l'intelligence UI, le composant `.razor` est une coquille de rendu,
les dépendances externes sont derrière des ports (interfaces).

## Quand utiliser ce skill

- Création d'un nouvel écran ou composant avec logique UI non triviale
- Cycle TDD sur un comportement UI (visibilité, transitions, machine à états)
- Refactoring d'un composant `.razor` trop chargé en logique
- Création d'un Fake Gateway pour les tests

## Architecture en 3 couches

```
UI.Domain (C# pur, 0 dépendance Blazor)
├── Presenters/         → Intelligence UI : états, transitions, propriétés dérivées
└── Ports/              → Interfaces des dépendances (IXxxGateway)

UI.Infrastructure
└── Gateways/           → Implémentations HTTP des ports

UI.Blazor
└── Pages|Components/   → Coquilles de rendu, binding uniquement
```

La flèche de dépendance va toujours vers le Domain : Blazor → Domain ← Infrastructure.

---

## Workflow TDD recommandé

### Phase 1 — Identifier le comportement UI à coder

Lister les règles de comportement sous forme de phrases :
- "Quand je clique sur X, le panneau Y apparaît"
- "Quand le chargement échoue, le bouton Réessayer est visible"
- "Quand je filtre par catégorie Z, seuls les éléments Z sont affichés"

Chaque phrase deviendra un test.

### Phase 2 — Écrire le test en premier

Suivre ce template :

```csharp
[Fact]
public async Task Action_doit_resultat_quand_contexte()
{
    // Arrange — configurer le Fake et le Presenter
    var gateway = new FakeXxxGateway().AvecDonnees(...);
    var presenter = new XxxPresenter(gateway);

    // Act — déclencher l'action utilisateur
    await presenter.FaireQuelqueChoseAsync();

    // Assert — vérifier l'état résultant
    presenter.ProprieteVisible.Should().BeTrue();
}
```

### Phase 3 — Implémenter le minimum dans le Presenter

Faire passer le test, pas plus. Puis refactorer si nécessaire.

### Phase 4 — Câbler le composant .razor

Le composant ne fait que binder. Pas de logique à tester ici hormis le câblage HTML critique (optionnel, bUnit).

---

## Templates de code

### Template Presenter

```csharp
namespace [Namespace].Presenters.[Feature];

using [Namespace].Ports;

public class [Feature]Presenter
{
    private readonly I[Feature]Gateway _gateway;

    public [Feature]Presenter(I[Feature]Gateway gateway)
    {
        _gateway = gateway;
    }

    // ── État observable ──

    public EtatChargement Etat { get; private set; } = EtatChargement.Inactif;
    public string? MessageErreur { get; private set; }

    // ── Propriétés dérivées (logique de visibilité) ──

    public bool ChargementVisible => Etat == EtatChargement.EnCours;
    public bool ErreurVisible => MessageErreur is not null;
    public bool ContenuVisible => Etat == EtatChargement.Charge;

    // ── Notification vers Blazor ──

    public event Action? OnChanged;
    private void Notifier() => OnChanged?.Invoke();

    // ── Actions / Transitions ──

    public async Task ChargerAsync()
    {
        Etat = EtatChargement.EnCours;
        MessageErreur = null;
        Notifier();

        try
        {
            // appel gateway...
            Etat = EtatChargement.Charge;
        }
        catch (Exception ex)
        {
            Etat = EtatChargement.EnErreur;
            MessageErreur = $"Erreur : {ex.Message}";
        }

        Notifier();
    }
}
```

### Template EtatChargement (réutilisable)

```csharp
public enum EtatChargement
{
    Inactif,
    EnCours,
    Charge,
    EnErreur
}
```

Ce type est partagé entre tous les Presenters. Le placer dans `Presenters/Commun/` ou à la racine de `Presenters/`.

### Template Port (Gateway)

```csharp
public interface I[Feature]Gateway
{
    Task<IReadOnlyList<[Model]>> RecupererTousAsync();
    Task<[DetailModel]> RecupererDetailAsync(int id);
}
```

Règles pour les ports :
- Nommage : `I[Feature]Gateway` (pas Repository — on est côté frontend)
- Types de retour : DTOs immuables (`record struct` ou `record`)
- Pas de `HttpClient`, `HttpResponseMessage` ou autre détail HTTP dans la signature
- Task-based systématiquement (même si le Fake retourne `Task.FromResult`)

### Template Fake Gateway

```csharp
public class Fake[Feature]Gateway : I[Feature]Gateway
{
    private IReadOnlyList<[Model]> _donnees = [];
    private Exception? _exception;

    // ── API fluide de configuration ──

    public Fake[Feature]Gateway AvecDonnees(params [Model][] donnees)
    {
        _donnees = donnees;
        return this;
    }

    public Fake[Feature]Gateway QuiEchoue(string message = "Erreur réseau")
    {
        _exception = new HttpRequestException(message);
        return this;
    }

    // ── Implémentation du port ──

    public Task<IReadOnlyList<[Model]>> RecupererTousAsync()
    {
        if (_exception is not null) throw _exception;
        return Task.FromResult(_donnees);
    }
}
```

Principes du Fake :
- API fluide en français : `AvecXxx(...)`, `QuiEchoueXxx(...)`, `SansResultat()`
- Retourne `Task.FromResult` pour garder les tests synchrones et ultra-rapides
- Un Fake par Gateway, placé dans `Tests/Presenters/Fakes/`

### Template Composant .razor

```razor
@implements IDisposable
@inject [Feature]Presenter Presenter

@if (Presenter.ChargementVisible)
{
    <div class="spinner">Chargement…</div>
}

@if (Presenter.ErreurVisible)
{
    <div class="erreur">@Presenter.MessageErreur</div>
}

@if (Presenter.ContenuVisible)
{
    @* Rendu du contenu — aucune logique ici *@
}

@code {
    protected override async Task OnInitializedAsync()
    {
        Presenter.OnChanged += OnPresenterChanged;
        await Presenter.ChargerAsync();
    }

    private void OnPresenterChanged() => InvokeAsync(StateHasChanged);

    public void Dispose() => Presenter.OnChanged -= OnPresenterChanged;
}
```

Points d'attention du câblage Blazor :
- Toujours `InvokeAsync(StateHasChanged)`, pas `StateHasChanged()` directement (thread-safety)
- Toujours `IDisposable` + désabonnement dans `Dispose()`
- Le Presenter est injecté via DI (`AddScoped<TPresenter>()`)
- Aucune instruction `if/else` métier ou UI dans le `@code` — tout dans le Presenter

### Template fichier de tests

```csharp
namespace [Namespace].Tests.Presenters.[Feature];

using [Namespace].Presenters.[Feature];
using [Namespace].Tests.Presenters.Fakes;
using FluentAssertions;

public class [Feature]Presenter_[Aspect]Tests
{
    // ── Données de test réutilisables ──

    private static readonly [Model] _donnee1 = new(...);
    private static readonly [Model] _donnee2 = new(...);

    // ── Helper optionnel ──

    private async Task<[Feature]Presenter> CreerPresenterCharge(
        params [Model][] donnees)
    {
        var gateway = new Fake[Feature]Gateway().AvecDonnees(donnees);
        var presenter = new [Feature]Presenter(gateway);
        await presenter.ChargerAsync();
        return presenter;
    }

    // ── Tests ──

    [Fact]
    public async Task Action_doit_resultat_quand_contexte()
    {
        // Arrange
        var presenter = await CreerPresenterCharge(_donnee1, _donnee2);

        // Act
        presenter.FaireQuelqueChose();

        // Assert
        presenter.ProprieteVisible.Should().BeTrue();
    }
}
```

**⚠️ Les commentaires `// Arrange`, `// Act`, `// Assert` sont OBLIGATOIRES dans chaque méthode de test. Ne jamais les omettre, même pour les tests courts.**

Convention de découpage des fichiers de tests :
- Un fichier par aspect du Presenter : `_AffichageTests`, `_FiltreTests`, `_NavigationTests`, `_ErreurTests`
- Les données de test sont des `static readonly` en haut de classe
- Un helper `CreerPresenterCharge` quand plusieurs tests partagent le même setup

---

## Enregistrement DI

**⚠️ Les DEUX enregistrements ci-dessous sont obligatoires. Un oubli compile mais crashe au runtime avec `CannotResolveService`.**

```csharp
// Program.cs

// 1. Ports → Adapters (OBLIGATOIRE — sinon le Presenter ne peut pas résoudre son gateway)
builder.Services.AddHttpClient<I[Feature]Gateway, Http[Feature]Gateway>(client =>
{
    client.BaseAddress = new Uri(builder.Configuration["ApiBaseUrl"]!);
});

// 2. Presenters — Scoped (OBLIGATOIRE — sinon le composant .razor ne peut pas s'injecter)
builder.Services.AddScoped<[Feature]Presenter>();
```

Le Presenter est **Scoped**, pas Singleton ni Transient :
- Scoped = un par circuit/utilisateur en Blazor Server, un par tab en WASM
- Singleton serait partagé entre utilisateurs (dangereux)
- Transient recréerait le Presenter à chaque injection (perte d'état)

**Règle de vérification** : après chaque scaffolding ou implémentation, ouvrir `Program.cs` et vérifier que la chaîne DI complète est enregistrée : `Gateway` + `Presenter`. Chaque Presenter qui injecte un port dans son constructeur nécessite que ce port soit enregistré.

---

## Pièges courants à éviter

### 1. Logique dans le .razor
Si tu écris `@if (items.Count > 0 && !isLoading && selectedItem is null)` dans le `.razor`,
c'est un signal : cette condition doit être une propriété dérivée du Presenter.

### 2. Sur-ingénierie
Un simple toggle `IsOpen` sans combinatoire ne justifie pas un Presenter.
Critère : "Est-ce qu'il y a plus d'un test intéressant à écrire ?" Si non, rester dans le `.razor`.

### 3. StateHasChanged sans InvokeAsync
En Blazor Server, `OnChanged` peut être invoqué depuis un thread non-UI.
Toujours `InvokeAsync(StateHasChanged)`.

### 4. Oublier le Dispose
Si le composant ne se désabonne pas de `OnChanged`, le Presenter garde une référence
vers un composant mort → fuite mémoire + crash potentiel.

### 5. Logique métier dans le Presenter
Le Presenter gère la logique UI (visibilité, états d'écran, navigation).
La logique métier (calcul de prix, validation de règles métier) reste côté backend.
Si une règle métier est nécessaire côté UI (ex: validation temps réel), elle vient du backend
via le Gateway sous forme de règle pré-calculée, pas implémentée dans le Presenter.

---

## Checklist avant PR

- [ ] Le Presenter n'a aucun `using Microsoft.AspNetCore.Components`
- [ ] Chaque propriété de visibilité a au moins un test
- [ ] Le Fake Gateway couvre le cas nominal ET le cas d'erreur
- [ ] Le composant `.razor` ne contient aucune logique conditionnelle non triviale
- [ ] `InvokeAsync(StateHasChanged)` est utilisé (pas `StateHasChanged()`)
- [ ] `IDisposable` + désabonnement `OnChanged` sont implémentés
- [ ] Le Presenter est enregistré en Scoped dans le DI
