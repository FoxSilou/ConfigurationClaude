---
name: code-review-fr
description: >
  Grille de revue de code alignée sur les conventions du workspace (DDD, TDD, hexagonal, ubiquitous language français).
  À invoquer quand l'utilisateur demande une revue de code, une relecture critique, ou un avis sur un diff / PR.
user-invocable: true
---

# Revue de code — conventions du workspace

Grille de lecture d'un diff, d'un fichier, ou d'une PR. L'objectif n'est pas de cocher des cases mais d'identifier ce qui **s'éloigne de l'intention** (domaine clair, tests d'abord, simplicité, lisibilité).

Sortie attendue : un rapport structuré en **Bloquants / Recommandés / Suggestions**, en français, concis, pointant fichier:ligne.

---

## 1. Domaine d'abord

- Le nom des types, méthodes, variables utilise-t-il l'**ubiquitous language français** du bounded context ?
- La logique métier est-elle dans le `Domain` (Aggregate / VO / Domain Event) ou a-t-elle fui vers `Application` / `Infrastructure` / composant Blazor ?
- Un concept implicite mérite-t-il d'être extrait en Value Object ?
- Les invariants sont-ils protégés par le constructeur de l'Aggregate (pas de setter public, pas d'état invalide atteignable) ?

**Red flags** : `public set`, primitives obsessionnelles (`string email`, `Guid id` non typé), logique métier dans un `Controller`, un `Handler`, ou un `.razor`.

## 2. Tests d'abord

- Chaque ligne de production a-t-elle un test qui l'exige ? (git blame conceptuel : "quel test aurait échoué sans ça ?")
- Les tests testent-ils **du comportement** (via l'API publique de l'agrégat ou du Presenter) ou de l'implémentation ?
- Backend : tests sur **Commands uniquement** (pas de test unitaire de Query — voir rules).
- Frontend : tests sur **Presenter**, pas sur le composant. Commentaires `// Arrange`, `// Act`, `// Assert` présents.
- Nommage backend : `<Command>Doit_<comportement>_quand_<contexte>`. Nommage frontend : `Action_doit_resultat_quand_contexte`.
- Pas de `Mock` / `NSubstitute` / `Moq` — uniquement des **fakes** explicites.

**Red flags** : tests écrits après coup ("on ajoutera les tests plus tard"), tests qui appellent des internes, `Mock<>`, tests sans AAA.

## 3. CQRS & architecture (backend)

- Command et Query séparées ? Pas de Query qui modifie, pas de Command qui retourne du read model.
- MediatR traité comme un adapter (namespace `Infrastructure`), jamais de `IRequest` dans le Domain.
- Les Repositories sont des **ports** (interface dans Domain) — EF Core reste dans Infrastructure.
- Event Sourcing : l'état est reconstitué depuis les events, pas depuis une table EF.
- Les Pipeline Behaviors traitent des préoccupations transverses (logging, validation, transaction), pas de métier.

## 4. Architecture hexagonale (frontend)

- Les Presenters sont-ils purs (aucun `using Microsoft.AspNetCore.Components`) ?
- Les Gateways consomment-ils le client **NSwag généré** (`IImperiumRexApiClient`), pas un `HttpClient` brut ?
- Aucune URL d'endpoint backend hardcodée.
- Composants Radzen encapsulés dans `Components/Kit/` (jamais `<RadzenXxx>` dans une page métier).
- `data-testid` sur les éléments testés par Playwright (jamais sélecteur CSS / texte).

## 5. Simplicité

- Y a-t-il une abstraction qui n'a qu'**une seule implémentation** et qu'aucun test ne justifie ? → supprimer.
- Un helper / extension method apporte-t-il de la valeur ou déplace-t-il juste du code ?
- Y a-t-il du code **mort** (branches inatteignables, `if` toujours vrai, paramètres inutilisés) ?
- Un `try/catch` avale-t-il une exception sans décision métier ?
- Des commentaires expliquent-ils le **quoi** au lieu du **pourquoi** ? (si oui : renommer plutôt que commenter)

## 6. Lisibilité

- Un lecteur neuf comprend-il l'intention en 5 minutes sans ouvrir d'autres fichiers ?
- Les noms sont-ils honnêtes (pas de `Manager`, `Helper`, `Utils`, `Data` vide de sens) ?
- La fonction tient-elle dans un écran ? Un niveau d'abstraction par fonction ?
- Pas de `/// <summary>` sur propriétés / méthodes / classes (XML docs interdits — nommage suffisant).

## 7. Conventions transverses

- Dates : `DateTimeOffset` (jamais `DateTime` nu).
- Ids : Value Objects typés (jamais `Guid` brut en paramètre métier).
- Async : `Task` (pas `ValueTask` sauf justification perf mesurée).
- Langue : **français** pour domaine / commentaires métier, **anglais** uniquement pour le technique pur (noms de patterns, libs tierces).

---

## Format de sortie recommandé

```markdown
## Revue de <cible>

### Bloquants
- **<fichier>:<ligne>** — <description concise>. <correction attendue>.

### Recommandés
- ...

### Suggestions
- ...

### Points positifs
- <1-3 choses faites correctement, pour ancrer le feedback>
```

Un commentaire sans fichier:ligne est inutile — toujours ancrer dans le code.
