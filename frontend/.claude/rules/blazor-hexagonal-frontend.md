# Règle : Architecture Hexagonale Frontend Blazor

## Principe

Tout composant Blazor avec une logique UI non triviale (combinatoire d'états, visibilité conditionnelle, machine à états, règles d'activation croisées) DOIT déléguer cette logique à un **Presenter** C# pur, sans aucune dépendance Blazor.

Le composant `.razor` est une **coquille de rendu** : il binde l'état du Presenter, appelle ses méthodes sur les événements DOM, et s'abonne à `OnChanged` pour déclencher `StateHasChanged`.

## Critère de déclenchement

Extraire un Presenter dès qu'un composant contient :
- Plus d'un booléen de visibilité interdépendant
- Une logique conditionnelle dans un `@onclick` ou `@onchange`
- Un enchaînement d'états (chargement → succès/erreur)
- Une combinatoire testable (filtre × sélection × état de chargement)

Ne PAS extraire pour un simple toggle isolé sans combinatoire.

## Structure attendue

- `MonApp.UI.Domain/Presenters/` — Presenters C# purs, testables en xUnit
- `MonApp.UI.Domain/Ports/` — Interfaces des gateways (appels API)
- `MonApp.UI.Infrastructure/Gateways/` — Implémentations HTTP des ports
- `MonApp.UI.Domain.Tests/Presenters/` — Tests unitaires xUnit + FluentAssertions
- `MonApp.UI.Domain.Tests/Presenters/Fakes/` — Fakes configurables des gateways

## Convention de test

Les tests ciblent le Presenter, jamais le composant. Nommage : `{Presenter}_{Comportement}Tests.cs`.
Les noms de méthodes de test suivent le format : `Action_doit_resultat_quand_contexte`.
