# ConfigurationClaude

## But du projet

Ce dépôt est une **factory Claude Code** : un workspace préconfiguré (agents, skills, slash commands, conventions) destiné à piloter la construction d'un projet logiciel de bout en bout avec Claude Code.

Le livrable principal n'est pas le code .NET présent dans `backend/` et `frontend/` (qui sert de terrain d'application et de validation), mais **l'ensemble des fichiers de configuration `.md`** : `CLAUDE.md`, agents, skills et commandes qui encadrent le workflow.

La philosophie est celle d'un artisan logiciel : DDD, TDD strict, simplicité, domaine d'abord (voir `CLAUDE.md` pour le détail).

## Structure du workspace

```
workspace/
├── .claude/        ← agents + skills partagés (niveau workspace)
├── backend/        ← solution backend (.NET) + conventions propres
├── frontend/       ← solution frontend (.NET/Blazor) + conventions propres
├── CLAUDE.md       ← philosophie partagée + carte des agents/commandes
└── README.md       ← ce fichier
```

## Workflow de base pour construire un projet

Le workflow suit un enchaînement discovery → spec → scaffolding → implémentation TDD.

### 1. Discovery du domaine

```
/task-event-storming
```
Atelier d'Event Storming : acteurs, commandes, événements, read models, bounded contexts. Produit des livrables markdown + diagrammes Excalidraw.

### 2. Spécifications

Deux branches parallèles, dérivées du storming :

```
/task-bdd-workshop        → Example Mapping + fichiers Gherkin (spec backend)
/task-ui-discovery        → Inventaire écrans, user flows, Presenter specs (spec frontend)
```

### 3. Priorisation MVP

```
/task-story-mapping
```
Consolide BDD + UI Discovery en une roadmap MVP ordonnée (user stories verticales).

### 4. Scaffolding

```
/task-scaffold-back                              → fondation backend
/task-scaffold-back <BC> <Aggregate>            → plumbing par agrégat
/task-scaffold-front                             → fondation frontend + harness de test
```

### 5. Implémentation TDD

Dans l'ordre des stories du story map :

```
/task-implement-feature-back             → TDD backend (gate utilisateur RED/GREEN/REFACTOR)
/task-implement-feature-auto-back        → variante autonome (un seul gate final)
/task-implement-feature-front            → TDD Presenter frontend
```

### 6. Correction de bugs

```
/task-investigate-bug     → investigation cross-repo (frontend + backend)
/task-fix-bug-back        → fix test-first
/task-refactor-back       → refactor iso-fonctionnel sous tests verts
```

## Schéma récapitulatif

```
event-storming
      │
      ├── bdd-workshop ─────────┐
      │                          │
      └── ui-discovery ──────────┤
                                 ▼
                          story-mapping
                                 │
                                 ▼
                    scaffold-back / scaffold-front
                                 │
                                 ▼
             implement-feature-back / implement-feature-front
                                 │
                                 ▼
                   investigate-bug → fix-bug / refactor
```

## Pour aller plus loin

- `CLAUDE.md` — philosophie, identité craftsman, carte complète des agents et commandes
- `backend/CLAUDE.md` — conventions backend (DDD, CQRS, tests)
- `frontend/CLAUDE.md` — conventions frontend (Presenters, bUnit, Playwright)
