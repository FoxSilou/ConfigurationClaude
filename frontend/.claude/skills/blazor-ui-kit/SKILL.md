---
name: blazor-ui-kit
description: >
  Utiliser quand l'utilisateur crée un composant UI, un wrapper Radzen, une grille, un dialogue,
  un formulaire, ou câble un composant avec un Presenter. Aussi quand il mentionne Radzen,
  DataGrid, Dialog, kit UI, ou veut remplacer un usage direct de Radzen par un wrapper maison.
user-invocable: false
---

# Blazor UI Kit — Encapsulation Radzen

Ce skill guide la création de composants wrapper autour de Radzen Blazor
et leur intégration avec l'architecture hexagonale frontend (Presenters).

## Principes d'encapsulation

### Pourquoi encapsuler

Un composant Radzen comme `RadzenDataGrid<T>` expose des dizaines de Parameter.
Dans la pratique, on en utilise 5 ou 6. Exposer tout crée un couplage fort :
si Radzen change une API ou si on migre vers une autre lib, chaque page est impactée.

Le wrapper agit comme un **port UI** : il traduit le vocabulaire de l'application
vers celui de la bibliothèque, exactement comme un Gateway traduit vers HTTP.

### Règles d'encapsulation

1. **N'exposer que les Parameter Radzen utilisés** — pas de passthrough générique des Parameter Radzen. En revanche, toujours capturer les attributs HTML standards (`data-testid`, `id`, `aria-*`) via `[Parameter(CaptureUnmatchedValues = true)]` et `@attributes="AttributsSupplementaires"` sur l'élément racine
2. **Nommer en français avec le vocabulaire métier** quand pertinent (`Colonnes`, `Source`, `EnChargement`)
3. **Centraliser les valeurs par défaut** dans le wrapper (taille de page, format de date, densité)
4. **Un `@using Radzen` ne doit jamais apparaître dans une page métier** — uniquement dans les wrappers
5. **Noms directs sans préfixe** : `DataGrid`, `Dialog`, `Button`, `TextBox`, `DropDown`, `[Projet]DialogService`

### Structure de dossiers

```
UI.Blazor/
├── Components/
│   ├── Kit/                    ← Wrappers Radzen (seul endroit avec @using Radzen)
│   │   ├── _Imports.razor      ← @using Radzen ici uniquement
│   │   ├── DataGrid.razor
│   │   ├── Dialog.razor
│   │   ├── Button.razor
│   │   ├── TextBox.razor
│   │   └── Notification.razor
│   └── Shared/                 ← Composants métier réutilisables (utilisent les wrappers Kit)
│       ├── PanneauDetail.razor
│       └── BarreRecherche.razor
├── Pages/                      ← Pages métier (utilisent wrappers Kit et Shared/)
│   └── Articles.razor
└── Layout/
```

Le `_Imports.razor` dans `Kit/` contient :
```razor
@using Radzen
@using Radzen.Blazor
```

Les `_Imports.razor` des autres dossiers n'ont PAS ces using.

---

## Templates de wrappers

### DataGrid — Grille de données

```razor
@typeparam TItem

<RadzenDataGrid Data="@Source"
                TItem="TItem"
                AllowPaging="@Pagination"
                PageSize="@TaillePage"
                AllowSorting="@TriAutorise"
                IsLoading="@EnChargement"
                Density="Density.Compact"
                class="@CssClass"
                RowSelect="@OnLigneSelectionnee"
                Count="@NombreTotal"
                LoadData="@OnChargementDemande"
                @attributes="AttributsSupplementaires">
    @Colonnes
</RadzenDataGrid>

@code {
    [Parameter, EditorRequired]
    public IEnumerable<TItem> Source { get; set; } = [];

    [Parameter, EditorRequired]
    public RenderFragment? Colonnes { get; set; }

    [Parameter]
    public bool EnChargement { get; set; }

    [Parameter]
    public bool Pagination { get; set; } = true;

    [Parameter]
    public int TaillePage { get; set; } = 20;

    [Parameter]
    public bool TriAutorise { get; set; } = true;

    [Parameter]
    public int NombreTotal { get; set; }

    [Parameter]
    public EventCallback<TItem> OnLigneSelectionnee { get; set; }

    [Parameter]
    public EventCallback<LoadDataArgs> OnChargementDemande { get; set; }

    [Parameter]
    public string? CssClass { get; set; }

    [Parameter(CaptureUnmatchedValues = true)]
    public Dictionary<string, object>? AttributsSupplementaires { get; set; }
}
```

#### Usage dans une page métier

```razor
<DataGrid TItem="ArticleResume"
             Source="@Presenter.ArticlesAffiches"
             EnChargement="@Presenter.IndicateurChargementListeVisible"
             OnLigneSelectionnee="OnArticleSelectionne">
    <Colonnes>
        <RadzenDataGridColumn TItem="ArticleResume" Property="Titre" Title="Titre" />
        <RadzenDataGridColumn TItem="ArticleResume" Property="Categorie" Title="Catégorie" Width="150px" />
        <RadzenDataGridColumn TItem="ArticleResume" Property="DatePublication" Title="Date" Width="120px"
                              FormatString="{0:dd/MM/yyyy}" />
    </Colonnes>
</DataGrid>

@code {
    private async Task OnArticleSelectionne(ArticleResume article)
    {
        await Presenter.SelectionnerArticleAsync(article.Id);
    }
}
```

Note : les `RadzenDataGridColumn` restent typés Radzen à l'intérieur du `RenderFragment`.
C'est un compromis pragmatique — encapsuler chaque colonne ajouterait de la complexité
sans gain réel. Si la migration de lib est nécessaire, les colonnes seront adaptées
en même temps que le wrapper, pas page par page.

---

### Dialog — Dialogue modal

```razor
<RadzenDialog @ref="_dialog" />

@code {
    private RadzenDialog _dialog = default!;

    [Inject]
    private DialogService DialogService { get; set; } = default!;
}
```

Le dialogue Radzen fonctionne via un service (`DialogService`). L'encapsulation passe
par un **service wrapper maison** plutôt qu'un composant :

```csharp
namespace MonApp.UI.Blazor.Components.Kit;

using Radzen;

public class [Projet]DialogService
{
    private readonly DialogService _radzenDialog;

    public [Projet]DialogService(DialogService radzenDialog)
    {
        _radzenDialog = radzenDialog;
    }

    public async Task<bool> ConfirmerAsync(string titre, string message)
    {
        var result = await _radzenDialog.Confirm(message, titre,
            new ConfirmOptions
            {
                OkButtonText = "Confirmer",
                CancelButtonText = "Annuler"
            });

        return result == true;
    }

    public async Task AfficherAsync<TComponent>(string titre,
        Dictionary<string, object>? parametres = null) where TComponent : ComponentBase
    {
        await _radzenDialog.OpenAsync<TComponent>(titre,
            parametres ?? [],
            new DialogOptions
            {
                Width = "600px",
                CloseDialogOnOverlayClick = true
            });
    }

    public void Fermer() => _radzenDialog.Close();
}
```

#### Enregistrement DI

```csharp
// Program.cs
builder.Services.AddScoped<DialogService>();      // Radzen
builder.Services.AddScoped<[Projet]DialogService>();    // Wrapper maison
```

---

### Button — Bouton

```razor
<RadzenButton Text="@Libelle"
              ButtonStyle="@Style"
              Disabled="@Desactive"
              IsBusy="@EnCours"
              Click="@OnClic"
              class="@CssClass"
              @attributes="AttributsSupplementaires" />

@code {
    [Parameter, EditorRequired]
    public string Libelle { get; set; } = "";

    [Parameter]
    public EventCallback OnClic { get; set; }

    [Parameter]
    public bool Desactive { get; set; }

    [Parameter]
    public bool EnCours { get; set; }

    [Parameter]
    public ButtonStyle Style { get; set; } = ButtonStyle.Primary;

    [Parameter]
    public string? CssClass { get; set; }

    [Parameter(CaptureUnmatchedValues = true)]
    public Dictionary<string, object>? AttributsSupplementaires { get; set; }
}
```

---

### TextBox — Champ texte

```razor
<RadzenTextBox Value="@Valeur"
               Placeholder="@Placeholder"
               Disabled="@Desactive"
               MaxLength="@LongueurMax"
               Change="@OnValeurChange"
               class="@CssClass"
               @attributes="AttributsSupplementaires" />

@code {
    [Parameter]
    public string? Valeur { get; set; }

    [Parameter]
    public EventCallback<string> OnValeurChange { get; set; }

    [Parameter]
    public string? Placeholder { get; set; }

    [Parameter]
    public bool Desactive { get; set; }

    [Parameter]
    public int? LongueurMax { get; set; }

    [Parameter]
    public string? CssClass { get; set; }

    [Parameter(CaptureUnmatchedValues = true)]
    public Dictionary<string, object>? AttributsSupplementaires { get; set; }
}
```

---

### FieldBox — Champ piloté par un Field Presenter

Quand un champ de formulaire est associé à un Field Presenter (voir skill `blazor-hexagonal`),
le wrapper reçoit le Presenter complet en paramètre au lieu de propriétés individuelles.
Il affiche automatiquement le message d'erreur.

```razor
@using MonApp.UI.Domain.Presenters

<div>
    <RadzenTextBox Value="@Presenter.Texte"
                   Placeholder="@Presenter.Placeholder"
                   Disabled="@Presenter.Desactive"
                   Change="@OnChange"
                   class="@CssClass"
                   @attributes="AttributsSupplementaires"/>
    @if (Presenter.EstEnErreur)
    {
        <div class="font-color-info">@Presenter.MessageErreur</div>
    }
</div>

@code {
    [Parameter, EditorRequired]
    public [Champ]Presenter Presenter { get; set; }

    [Parameter, EditorRequired]
    public EventCallback<string> OnValeurChange { get; set; }

    [Parameter]
    public string? CssClass { get; set; }

    [Parameter(CaptureUnmatchedValues = true)]
    public Dictionary<string, object>? AttributsSupplementaires { get; set; }

    private Task OnChange(string val) => OnValeurChange.InvokeAsync(val);
}
```

Conventions :
- **Nom** : le concept du champ sans préfixe — `EmailBox`, `PasswordBox`, `PseudonymeBox`
- Le composant Radzen interne varie selon le type : `RadzenTextBox`, `RadzenPassword`, etc.
- Le wrapper vit dans `Components/Kit/` avec les autres wrappers
- La page câble `Presenter="@Presenter.Email"` et `OnValeurChange="@Presenter.DefinirEmail"`

Exemples existants : `EmailBox.razor`, `PasswordBox.razor`, `PseudonymeBox.razor`

---

### DropDown — Liste déroulante

```razor
@typeparam TValue

<RadzenDropDown TValue="TValue"
                Data="@Source"
                Value="@Valeur"
                TextProperty="@ProprieteTexte"
                ValueProperty="@ProprieteValeur"
                Placeholder="@Placeholder"
                Disabled="@Desactive"
                AllowClear="@EffacableAutorise"
                Change="@OnChangement"
                class="@CssClass"
                @attributes="AttributsSupplementaires" />

@code {
    [Parameter, EditorRequired]
    public object Source { get; set; } = default!;

    [Parameter]
    public TValue? Valeur { get; set; }

    [Parameter]
    public string ProprieteTexte { get; set; } = "Libelle";

    [Parameter]
    public string ProprieteValeur { get; set; } = "Id";

    [Parameter]
    public string? Placeholder { get; set; }

    [Parameter]
    public bool Desactive { get; set; }

    [Parameter]
    public bool EffacableAutorise { get; set; } = true;

    [Parameter]
    public EventCallback<object> OnChangement { get; set; }

    [Parameter]
    public string? CssClass { get; set; }

    [Parameter(CaptureUnmatchedValues = true)]
    public Dictionary<string, object>? AttributsSupplementaires { get; set; }
}
```

---

## Câblage Presenter ↔ Wrapper

### Le contrat

Le Presenter ne connaît PAS les wrappers. Il expose des propriétés et des méthodes.
Le composant page fait le câblage :

```
Presenter (C# pur)          Page .razor            Wrapper (Kit/)
─────────────────           ──────────             ─────────────
.ArticlesAffiches ────────→ Source="@..."  ───────→ RadzenDataGrid.Data
.ChargementVisible ───────→ EnChargement="@..." ─→ RadzenDataGrid.IsLoading
.SelectionnerAsync() ←───── OnLigneSelectionnee ←─ RadzenDataGrid.RowSelect
```

Le Presenter ne sait pas qu'il y a une grille Radzen. Il pourrait alimenter un tableau HTML.
Le wrapper ne sait pas qu'il y a un Presenter. Il reçoit des données via ses Parameter.
La page fait le pont entre les deux.

### Pattern complet — Page avec Presenter et Wrappers

```razor
@page "/articles"
@implements IDisposable
@inject ListeArticlesPresenter Presenter

<h1>Articles</h1>

<DropDown TValue="string"
             Source="@Presenter.CategoriesDisponibles.Select(c => new { Id = c, Libelle = c })"
             Valeur="@Presenter.FiltreCategorie"
             ProprieteTexte="Libelle"
             ProprieteValeur="Id"
             Placeholder="Toutes les catégories"
             OnChangement="OnFiltreChange" />

<DataGrid TItem="ArticleResume"
             Source="@Presenter.ArticlesAffiches"
             EnChargement="@Presenter.IndicateurChargementListeVisible"
             OnLigneSelectionnee="OnArticleSelectionne">
    <Colonnes>
        <RadzenDataGridColumn TItem="ArticleResume" Property="Titre" Title="Titre" />
        <RadzenDataGridColumn TItem="ArticleResume" Property="Categorie" Title="Catégorie" Width="150px" />
    </Colonnes>
</DataGrid>

@if (Presenter.PanneauDetailVisible)
{
    <PanneauDetail Detail="@Presenter.DetailSelectionne!.Value"
                   EnChargement="@Presenter.IndicateurChargementDetailVisible"
                   OnFermer="Presenter.FermerDetail" />
}

@code {
    protected override async Task OnInitializedAsync()
    {
        Presenter.OnChanged += OnPresenterChanged;
        await Presenter.ChargerArticlesAsync();
    }

    private void OnPresenterChanged() => InvokeAsync(StateHasChanged);

    private async Task OnArticleSelectionne(ArticleResume article)
        => await Presenter.SelectionnerArticleAsync(article.Id);

    private void OnFiltreChange(object value)
    {
        if (value is string categorie && !string.IsNullOrEmpty(categorie))
            Presenter.FiltrerParCategorie(categorie);
        else
            Presenter.ReinitialiserFiltre();
    }

    public void Dispose() => Presenter.OnChanged -= OnPresenterChanged;
}
```

---

## Quand créer un nouveau wrapper

### Créer un wrapper si :
- Le composant Radzen est utilisé dans 2+ pages
- On veut figer des valeurs par défaut (taille de page, densité, format de date)
- On veut simplifier l'API (5 Parameter exposés au lieu de 30)
- On veut pouvoir remplacer le composant Radzen par un autre à terme

### Ne PAS créer de wrapper si :
- Le composant Radzen est utilisé une seule fois dans un contexte très spécifique
- Le wrapper serait un passthrough 1:1 sans simplification ni valeur par défaut
- C'est un composant de layout Radzen (RadzenRow, RadzenColumn) — utiliser directement

---

## Checklist avant PR — Composant UI

- [ ] Aucun `@using Radzen` dans les pages métier ou composants Shared
- [ ] Le wrapper n'expose que les Parameter effectivement utilisés
- [ ] Les valeurs par défaut sont centralisées dans le wrapper
- [ ] Le Presenter ne référence aucun type Radzen
- [ ] Le câblage Presenter ↔ Wrapper passe par la page (pas de couplage direct)

