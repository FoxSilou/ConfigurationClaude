# Règle : Encapsulation des composants UI tiers

## Principe

Les composants de bibliothèques UI tierces (Radzen, MudBlazor, etc.) ne sont JAMAIS utilisés
directement dans les pages ou composants métier. Ils sont systématiquement encapsulés dans un
**composant wrapper maison** qui n'expose que les `[Parameter]` strictement nécessaires à l'usage.

## Objectifs

- Pouvoir remplacer la bibliothèque UI sans toucher aux pages/composants métier
- Réduire la surface d'API exposée (pas de fuite d'abstraction)
- Centraliser la configuration par défaut (thème, taille, formats)
- Maintenir la cohérence du vocabulaire (noms français, conventions d'équipe)

## Convention de nommage

Les wrappers portent le nom du concept UI sans préfixe : `DataGrid`, `Dialog`, `Button`, `TextBox`, `DropDown`.
Pour les services, utiliser `[Projet]DialogService` pour éviter le conflit avec le `DialogService` Radzen.
Ils vivent dans le dossier `Components/Kit/`.

## Ce qui est interdit dans une page .razor

- `<RadzenDataGrid>`, `<RadzenButton>`, `<RadzenDialog>` ou tout composant Radzen direct
- Un `@using Radzen` dans une page métier

## Ce qui est autorisé

- `<DataGrid>`, `<Button>`, `<TextBox>` etc. dans les pages métier
- `@using Radzen` uniquement dans les fichiers wrapper (Components/Kit/)
