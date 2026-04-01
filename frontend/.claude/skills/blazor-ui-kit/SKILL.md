---
name: blazor-ui-kit
description: >
  Encapsulation de composants Radzen Blazor dans des wrappers maison (AppDataGrid, AppDialog, etc.)
  et câblage avec l'architecture hexagonale frontend (Presenter ↔ Wrapper).
  Utiliser ce skill chaque fois que l'utilisateur demande de créer un composant UI,
  un wrapper autour d'un composant Radzen, une grille de données, un dialogue, un formulaire,
  ou veut câbler un composant Radzen avec un Presenter. Également quand l'utilisateur mentionne
  Radzen, AppDataGrid, AppDialog, composant maison, kit UI, ou veut remplacer un usage direct
  de Radzen par un wrapper. Aussi pertinent quand l'utilisateur crée une nouvelle page Blazor
  qui a besoin de composants UI.
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

1. **N'exposer que les Parameter utilisés** — pas de passthrough générique
2. **Nommer en français avec le vocabulaire métier** quand pertinent (`Colonnes`, `Source`, `EnChargement`)
3. **Centraliser les valeurs par défaut** dans le wrapper (taille de page, format de date, densité)
4. **Un `@using Radzen` ne doit jamais apparaître dans une page métier** — uniquement dans les wrappers
5. **Préfixer `App`** : `AppDataGrid`, `AppDialog`, `AppButton`, `AppTextBox`, `AppDropDown`

### Structure de dossiers

```
UI.Blazor/
├── Components/
│   ├── Kit/                    ← Wrappers Radzen (seul endroit avec @using Radzen)
│   │   ├── _Imports.razor      ← @using Radzen ici uniquement
│   │   ├── AppDataGrid.razor
│   │   ├── AppDialog.razor
│   │   ├── AppButton.razor
│   │   ├── AppTextBox.razor
│   │   └── AppNotification.razor
│   └── Shared/                 ← Composants métier réutilisables (utilisent les App*)
│       ├── PanneauDetail.razor
│       └── BarreRecherche.razor
├── Pages/                      ← Pages métier (utilisent App* et Shared/)
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

### AppDataGrid — Grille de données

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
                LoadData="@OnChargementDemande">
    @Colonnes
</RadzenDataGrid>

@code {
    /// <summary>Données à afficher dans la grille.</summary>
    [Parameter, EditorRequired]
    public IEnumerable<TItem> Source { get; set; } = [];

    /// <summary>Template des colonnes (RadzenDataGridColumn via RenderFragment).</summary>
    [Parameter, EditorRequired]
    public RenderFragment? Colonnes { get; set; }

    /// <summary>Indique si la grille est en cours de chargement.</summary>
    [Parameter]
    public bool EnChargement { get; set; }

    /// <summary>Active la pagination.</summary>
    [Parameter]
    public bool Pagination { get; set; } = true;

    /// <summary>Nombre d'éléments par page.</summary>
    [Parameter]
    public int TaillePage { get; set; } = 20;

    /// <summary>Active le tri sur les colonnes.</summary>
    [Parameter]
    public bool TriAutorise { get; set; } = true;

    /// <summary>Nombre total d'éléments (pour pagination serveur).</summary>
    [Parameter]
    public int NombreTotal { get; set; }

    /// <summary>Callback quand une ligne est sélectionnée.</summary>
    [Parameter]
    public EventCallback<TItem> OnLigneSelectionnee { get; set; }

    /// <summary>Callback pour chargement serveur (pagination, tri).</summary>
    [Parameter]
    public EventCallback<LoadDataArgs> OnChargementDemande { get; set; }

    /// <summary>Classes CSS additionnelles.</summary>
    [Parameter]
    public string? CssClass { get; set; }
}
```

#### Usage dans une page métier

```razor
<AppDataGrid TItem="ArticleResume"
             Source="@Presenter.ArticlesAffiches"
             EnChargement="@Presenter.IndicateurChargementListeVisible"
             OnLigneSelectionnee="OnArticleSelectionne">
    <Colonnes>
        <RadzenDataGridColumn TItem="ArticleResume" Property="Titre" Title="Titre" />
        <RadzenDataGridColumn TItem="ArticleResume" Property="Categorie" Title="Catégorie" Width="150px" />
        <RadzenDataGridColumn TItem="ArticleResume" Property="DatePublication" Title="Date" Width="120px"
                              FormatString="{0:dd/MM/yyyy}" />
    </Colonnes>
</AppDataGrid>

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

### AppDialog — Dialogue modal

```razor
<RadzenDialog @ref="_dialog" />

@code {
    private RadzenDialog _dialog = default!;

    /// <summary>Service Radzen injecté pour piloter le dialogue.</summary>
    [Inject]
    private DialogService DialogService { get; set; } = default!;
}
```

Le dialogue Radzen fonctionne via un service (`DialogService`). L'encapsulation passe
par un **service wrapper maison** plutôt qu'un composant :

```csharp
namespace MonApp.UI.Blazor.Components.Kit;

using Radzen;

public class AppDialogService
{
    private readonly DialogService _radzenDialog;

    public AppDialogService(DialogService radzenDialog)
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
builder.Services.AddScoped<AppDialogService>();    // Wrapper maison
```

---

### AppButton — Bouton

```razor
<RadzenButton Text="@Libelle"
              ButtonStyle="@Style"
              Disabled="@Desactive"
              IsBusy="@EnCours"
              Click="@OnClic"
              class="@CssClass" />

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
}
```

---

### AppTextBox — Champ texte

```razor
<RadzenTextBox Value="@Valeur"
               Placeholder="@Placeholder"
               Disabled="@Desactive"
               MaxLength="@LongueurMax"
               Change="@OnValeurChange"
               class="@CssClass" />

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
}
```

---

### AppDropDown — Liste déroulante

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
                class="@CssClass" />

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

<AppDropDown TValue="string"
             Source="@Presenter.CategoriesDisponibles.Select(c => new { Id = c, Libelle = c })"
             Valeur="@Presenter.FiltreCategorie"
             ProprieteTexte="Libelle"
             ProprieteValeur="Id"
             Placeholder="Toutes les catégories"
             OnChangement="OnFiltreChange" />

<AppDataGrid TItem="ArticleResume"
             Source="@Presenter.ArticlesAffiches"
             EnChargement="@Presenter.IndicateurChargementListeVisible"
             OnLigneSelectionnee="OnArticleSelectionne">
    <Colonnes>
        <RadzenDataGridColumn TItem="ArticleResume" Property="Titre" Title="Titre" />
        <RadzenDataGridColumn TItem="ArticleResume" Property="Categorie" Title="Catégorie" Width="150px" />
    </Colonnes>
</AppDataGrid>

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
- [ ] Le wrapper a un commentaire `<summary>` sur chaque Parameter public
