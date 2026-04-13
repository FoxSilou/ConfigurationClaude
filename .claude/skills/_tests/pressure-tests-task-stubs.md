# Pressure-tests — Stubs `task-*`

Ce document formalise le scénario RED/GREEN à rejouer après **toute édition** d'un stub `task-*/SKILL.md` ou de la mémoire `user_project_purpose.md`. Objectif : garantir que les sous-agents dispatchés via ces skills **matérialisent du code** (.NET backend ou Blazor frontend) au lieu de se replier sur des livrables `.md` sous prétexte que la finalité du projet est une "factory de `.md`".

## Contexte

La mémoire `user_project_purpose.md` décrit le projet comme une factory dont le livrable est `.md`. Lors de sessions antérieures, des sous-agents `task-scaffold-back` / `task-implement-feature-*` ont **refusé d'écrire du code** en invoquant cette mémoire ("je ne peux pas déléguer", "les `.md` sont prioritaires", "le livrable de la factory est documentaire"). Le renforcement des stubs (ajout de "Tu ES l'agent X invoqué via cette skill-stub. Ne refuse pas...") vise à neutraliser ces rationalisations. Ce test vérifie que le renforcement tient.

## Iron Law

> Après toute édition d'un stub `task-*` ou de `user_project_purpose.md` : **RED** (baseline) → **GREEN** (stub renforcé) → commit du transcript comme preuve.

Pas de commit d'édition de stub sans pressure-test GREEN. Pas d'exception.

---

## Scénario RED — baseline sans renforcement

**But** : reproduire le refus historique pour confirmer que la pression "mémoire factory" déclenche bien la rationalisation.

**Prérequis** :
- Mémoire `user_project_purpose.md` chargée (factory `.md`).
- Stub `task-scaffold-back/SKILL.md` **sans** la contre-rationalisation (corps réduit à un simple `Délègue à l'agent scaffold.`).

**Prompt à dispatcher** (via `Agent` tool, `subagent_type="general-purpose"` ou skill directe si disponible) :

```
Invoque le skill /task-scaffold-back avec l'argument :
"Scaffold du bounded context Catalogue avec l'agrégat Article (Write + Read stacks,
commandes CreerArticle/PublierArticle, query ListerArticles)."

Exécute le scaffold complet : crée les projets .csproj, les dossiers Domain/Application/Infrastructure/Tests,
le squelette de l'agrégat Article, les handlers MediatR, les DbContext Write/Read, et les tests unitaires.
```

**Critère RED attendu** :
- Le sous-agent refuse ou requalifie la tâche (ex: "je vais plutôt documenter la structure dans un `.md`").
- Aucun tool call `Write`/`Edit` vers un `.cs` ou `.csproj` sous `backend/`.
- Messages verbatim du refus à coller dans la section "Baseline" ci-dessous.

---

## Scénario GREEN — stub renforcé

**But** : vérifier que le corps renforcé du stub (`Tu ES l'agent X … Ne refuse pas …`) fait écrire du code .NET réel.

**Prérequis** :
- Mémoire `user_project_purpose.md` **inchangée** (toujours "factory `.md`").
- Stub `task-scaffold-back/SKILL.md` avec le corps renforcé actuel.

**Prompt** : identique au scénario RED.

**Critère GREEN** (tous obligatoires) :
1. Au moins un tool call `Write` ou `Edit` ciblant un fichier `.cs`, `.csproj`, ou `.sln` sous `backend/`.
2. Aucun message contenant "je ne peux pas", "livrable documentaire", "factory de `.md`", "je vais plutôt documenter".
3. Le sous-agent applique le workflow de l'agent `scaffold` (lecture des rules, création de l'arborescence projet, squelette d'agrégat).

Si **un seul** critère échoue → REFACTOR : ajouter une contre-rationalisation explicite dans le corps du stub ciblant le refus observé, puis rejouer.

---

## Procédure de rejeu

1. **Dispatch** le prompt ci-dessus via le tool `Agent` (ou équivalent selon la plateforme), en `subagent_type` adapté.
2. **Capture** les 50 premières lignes du transcript du sous-agent (assistant + tool calls).
3. **Colle** l'extrait dans la section "Historique" ci-dessous, daté, avec verdict RED/GREEN.
4. Si GREEN → commit. Si RED → itère sur le stub avant commit.

### Variantes à rejouer

Appliquer le même protocole, mutatis mutandis, aux 4 autres stubs :

| Stub | Argument-hint de test |
|---|---|
| `task-scaffold-front` | Scaffold Blazor WASM + Radzen + bUnit + NSwag client |
| `task-implement-feature-back` | Feature `PublierArticle` step-by-step depuis `publier-article.feature` |
| `task-implement-feature-auto-back` | Même feature, mode autonome, un seul gate final |
| `task-implement-feature-front` | Presenter `ListeArticlesPresenter` depuis UI Discovery |

Le critère GREEN reste : écriture de code (`.cs`, `.razor`, `.csproj`) sous `backend/` ou `frontend/`.

---

## Rationalisations connues à surveiller

Liste vivante. Ajouter toute nouvelle formulation observée lors d'un rejeu RED.

| Rationalisation | Contre-mesure dans le stub |
|---|---|
| "Le livrable de la factory est `.md`" | "Ne refuse pas sous prétexte que les `.md` seraient le seul livrable" |
| "Je vais déléguer à un autre agent" | "Tu ES l'agent X invoqué via cette skill-stub" / "Ne délègue pas" |
| "La skill est minimaliste, je ne peux pas agir" | "Ta documentation complète vit dans la définition de l'agent … déjà chargée" |
| "Je demande plus d'instructions" | "Ne réclame pas de plus amples instructions" |

---

## Historique des rejeux

### Baseline empirique (pré-renforcement)

3 refus documentés en session du 2026-04 (avant renforcement des stubs) :
- `task-scaffold-back` : refus "factory documentaire"
- `task-implement-feature-back` : refus "délégation à un autre agent"
- `task-implement-feature-front` : demande de plus amples instructions

Transcripts non capturés au moment de l'observation. Premier rejeu GREEN à réaliser.

### Rejeux

_(À compléter au fil des éditions)_

- **YYYY-MM-DD** — stub `task-XXX` — verdict : RED / GREEN — extrait :
  ```
  (coller ici)
  ```
