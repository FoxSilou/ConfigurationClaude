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

## Field Presenters

Tout champ de formulaire dont le **type sémantique** porte un invariant **DOIT** être modélisé comme un **Field Presenter** : un `record` immutable avec un type `Valide` imbriqué (constructeur privé + factory `Result<Valide> Creer(string)`) qui garantit la validité **par construction**. Voir skill `blazor-hexagonal` pour les templates complets.

### Liste (non exhaustive) des types sémantiques concernés — Field Presenter obligatoire

`email`, `motDePasse`, `pseudonyme`, `identifiant`, `nomUtilisateur`, `telephone`, `url`, `iban`, `codePostal`, `numeroSiret`, `dateNaissance`, et tout champ dont la règle métier porte un format, une longueur minimale, ou un invariant contrôlable côté UI.

### Cas où un `string` nu est autorisé

Exclusivement les champs de **texte libre sans contrainte** : commentaire, description, recherche plein-texte, libellé saisi librement par l'utilisateur.

### Interdictions explicites

- **« Le backend valide, donc on peut laisser `string` »** n'est **pas** une justification valable. Le Field Presenter existe pour la type-safety UI (impossibilité structurelle de passer une valeur non validée au Gateway) et le feedback instantané — indépendamment de la revalidation backend.
- Un Presenter parent (`InscriptionPresenter`, `ConnexionPresenter`, etc.) ne doit **jamais** exposer `string Email`, `string MotDePasse` : il expose `EmailPresenter Email`, `MotDePassePresenter MotDePasse`.
- La signature d'un Gateway consommant un champ sémantique doit prendre le type `Valide` imbriqué : `InscrireAsync(EmailPresenter.Valide email, ...)` — jamais `string`.

### Portée de `Result<T>`

`Result<T>` est **réservé aux Field Presenters**. Les Presenters standards ne l'utilisent pas : ils signalent l'échec d'un appel Gateway via l'état `EnErreur` + `MessageErreur`, et déclenchent une Alert globale via `INotificationService`. Voir `gateway-error-handling.md`.

## OnChanged — règle d'usage

`OnChanged` ne doit être invoqué que dans les méthodes **async** pour signaler un état intermédiaire pendant un `await` (ex : afficher un spinner). Les setters synchrones appelés via event handlers Blazor (`Change`, `@onclick`, etc.) n'en ont **pas besoin** — Blazor re-rend automatiquement après le event handler.

## Structure attendue

- `MonApp.UI.Domain/Presenters/` — Presenters C# purs, testables en xUnit
- `MonApp.UI.Domain/Ports/` — Interfaces des gateways (appels API)
- `MonApp.UI.Infrastructure/Gateways/` — Implémentations HTTP des ports
- `MonApp.UI.Domain.Tests/Presenters/` — Tests unitaires xUnit + FluentAssertions
- `MonApp.UI.Domain.Tests/Presenters/Fakes/` — Fakes configurables des gateways

## Convention de test

Les tests ciblent le Presenter, jamais le composant. Nommage : `{Presenter}_{Comportement}Tests.cs`.
Les noms de méthodes de test suivent le format : `Action_doit_resultat_quand_contexte`.

### Commentaires AAA obligatoires

Chaque méthode de test DOIT contenir les commentaires `// Arrange`, `// Act`, `// Assert` pour structurer les trois phases. Pas d'exception, même pour les tests courts.

### Pas de commentaires XML

Le code doit être auto-documentant par le nommage. Les `/// <summary>` sont interdits sur les propriétés, méthodes et classes. Seuls les commentaires `// Arrange`, `// Act`, `// Assert` sont autorisés (dans les tests uniquement).
