# Règle : NavMenu par page

## Principe

La navigation principale n'est **pas** centralisée dans un composant `NavMenu` unique partagé par le `MainLayout`. Chaque page déclare sa propre entrée de navigation **dans sa propre définition** (auto-enregistrement).

## Pourquoi

- Une page qui disparaît emporte naturellement son entrée de menu (pas d'oubli, pas d'entrée morte).
- L'ajout d'une page n'oblige pas à modifier un fichier central partagé (réduction des conflits et du couplage).
- La page reste l'unité autonome de livraison.

## Ce qui est attendu

- Chaque page expose ses métadonnées de navigation (libellé, icône, ordre, éventuellement politique d'autorisation) via le mécanisme retenu par le projet (attribut, interface statique, ou enregistrement DI au démarrage).
- Le composant de navigation (layout) **découvre** les entrées par réflexion ou injection — il n'en liste aucune en dur.
- Une page sans métadonnée de navigation n'apparaît pas dans le menu (volontaire : ex. pages internes, détails).

## Ce qui est interdit

- Un `NavMenu.razor` contenant une liste `<NavLink>` en dur par page.
- Ajouter manuellement une entrée dans un fichier central lors de la création d'une page.
