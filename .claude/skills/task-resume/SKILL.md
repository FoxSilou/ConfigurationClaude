---
name: task-resume
description: Reprend une séquence de tâches multi-étapes après reset de contexte. Lit le fichier de progression du projet, identifie l'étape suivante, relance la commande correspondante. À utiliser quand l'utilisateur dit "continue", "reprends", "on enchaîne" après un /clear, ou invoque explicitement /task-resume.
user-invocable: true
argument-hint: "[chemin vers progression.md — optionnel, auto-détection si omis]"
context: inherit
---

# task-resume — reprise post-reset

Ce skill permet de reprendre une séquence d'étapes multi-sessions (scaffolding → features → bugs) après un reset de contexte, sans que l'utilisateur ait à re-briefer.

## Procédure

### 1. Localiser le fichier de progression

- Si un argument est fourni → le traiter comme chemin vers `progression.md`.
- Sinon → `Glob` sur `docs/story-mapping/*/progression.md`.
  - 0 candidat → informer l'utilisateur : « Aucun fichier de progression trouvé. Créez `docs/story-mapping/<projet>/progression.md` en premier. »
  - 1 candidat → l'utiliser.
  - ≥2 candidats → demander à l'utilisateur de choisir via `AskUserQuestion`.

### 2. Lire et analyser

Lire le fichier. Repérer le tableau de séquence (colonnes `#`, `Étape`, `Commande`, `Statut`).

Identifier **la première ligne** avec statut :
- `⏳ en cours` ou `⏳ prochaine` → c'est celle à lancer.
- sinon `⏸ à faire` → c'est celle à lancer.

Si toutes les lignes sont `✅ fait` → informer l'utilisateur que la séquence est terminée.

### 2.5. Sanity check — AVANT toute délégation

Vérifier la cohérence de la ligne à exécuter. Si un problème est détecté, **stopper et prévenir l'utilisateur** — ne jamais auto-corriger silencieusement la commande déléguée, ne jamais fabriquer de flag ad-hoc (ex. `--include-bc` inventé) pour contourner.

**a) Naming français (concepts domaine)**
Les arguments de commandes backend (BC, agrégat) doivent suivre la convention française. Si la colonne `Commande` contient un token anglais familier pour un concept domaine (`Identity`, `User`, `Auth`, `Game`, `Order`, etc.) ou si l'intitulé `Étape` mélange anglais/français pour un concept domaine, bloquer :

> « La ligne N référence `<token>` (anglais). Convention : concepts domaine en français (`Identite`, `Utilisateur`, `Authentification`…). Corrige `progression.md` avant que je délègue. »

**b) Prérequis de mode pour `/task-scaffold-back`**
- **2 args (Mode 3, agrégat)** → via `Glob`, vérifier que `backend/src/<BC>/` existe. Si absent : « Mode 3 demandé pour `<BC>/<Agg>` mais le BC n'est pas scaffolé. Scinde en 2a (BC) + 2b (agrégat) dans `progression.md` — une ligne par invocation, chacune son statut. »
- **1 arg (Mode 2, BC)** → vérifier que `backend/src/Shared/` existe. Si absent : prérequis Mode 1 manquant.

**b bis) Pas d'enchaînement dans une même ligne**
Si la colonne `Commande` d'une ligne contient plusieurs invocations (mot-clé `puis`, `&&`, deux backticks enchaînés, etc.) ou si l'intitulé contient « enchaîné », bloquer :

> « La ligne N enchaîne plusieurs invocations. Règle : une étape = une invocation = une ligne. Scinde en `Na` / `Nb` avec statuts séparés avant que je délègue. »

**c) Pas de flag inventé**
Les arguments passés à la skill déléguée sont exactement ceux de la colonne `Commande`. Toute instruction additionnelle (« enchaîner deux modes », « appliquer telle variante ») doit figurer en **prose claire dans l'intitulé de l'étape** et dans le prompt de délégation — jamais comme flag non documenté.

**d) Prérequis US front — backend livré**
Si la ligne à lancer est `/task-implement-feature-*-front` avec un `.feature` en argument :

- Chercher dans le tableau `Séquence` la ligne `/task-implement-feature-*-back` ayant **le même `.feature`** (même slug d'US).
- Si trouvée et statut ≠ `✅ fait` → bloquer :

  > « La ligne N lance le front pour `<slug>` mais la ligne M backend correspondante est `<statut>`. Backend d'abord — lance d'abord la ligne M, puis reviens. »

- Si introuvable → avertir non bloquant :

  > « Aucune ligne backend repérée pour cette US dans `progression.md`. Vérifie que c'est voulu avant de continuer. »

Cette vérif double celle de l'agent `implement-feature-front` (Phase -1) — `task-resume` attrape avant fork, l'agent attrape les chantiers hors-resume.

### 3. Annoncer et confirmer

Afficher à l'utilisateur :
- numéro et titre de l'étape
- commande exacte à lancer
- dernier bilan connu de l'étape précédente (pour contexte)

Attendre une confirmation brève (`ok`, `go`, `continue`) avant de lancer. Ne pas relancer automatiquement.

### 4. Exécuter

Invoquer la commande indiquée (via `Skill`). Si la commande prend des arguments (ex. `/task-scaffold-back Identite Utilisateur`, `/task-implement-feature-auto-back docs/bdd/.../xxx.feature`), les passer tels quels depuis la colonne `Commande`.

### 5. Mettre à jour la progression

Après exécution réussie, **relire d'abord `progression.md`** : les agents backend (`scaffold`, `implement-feature`, `fix-bug`, `refactor` + équivalents frontend) ont la responsabilité d'écrire leur propre bilan dans la section `## Bilans` et de passer leur ligne à `✅ fait` (cf. `backend/CLAUDE.md` § « Rapports d'exécution »). Donc :

- **Si la ligne de l'étape vient d'exécuter est déjà `✅ fait` et qu'un bilan horodaté a été ajouté** → ne rien toucher sur cette ligne, se contenter de passer l'étape suivante (s'il y en a une) à `⏳ prochaine`.
- **Sinon** (agent qui n'a pas respecté la convention) → faire la mise à jour complète :
  - passer le statut de l'étape à `✅ fait`.
  - passer l'étape suivante (s'il y en a une) à `⏳ prochaine`.
  - ajouter une entrée sous `## Bilans` avec titre `### Étape N — <titre> (YYYY-MM-DD)` et 3 à 8 puces (livrables, points de vigilance, liens).

Afficher le bilan complet à l'utilisateur et rappeler : « Tu peux reset le contexte. À la reprise, dis simplement "continue" ou relance /task-resume. »

## Format canonique de progression.md

### Règles de rédaction

- **Français pour les concepts domaine** — BC, agrégats, commands, Value Objects en français (`Identite`, `Utilisateur`, `InscrireUtilisateur`). Les mots techniques (scaffold, foundation, backend, frontend) restent en anglais s'ils n'ont pas d'équivalent ubiquitaire.
- **Une étape = une invocation = une ligne du tableau.** Scaffolding BC et scaffolding agrégat sont **deux lignes distinctes** (`2a` + `2b`), chacune avec son propre statut. Pas d'enchaînement dans une même ligne — même avec l'intitulé « enchaîné ». Pour matérialiser un couplage logique, utiliser une numérotation `Na`/`Nb` (éventuellement commentée au-dessus du tableau).
- **Argument de commande = argument réel de la skill.** Pas de flag inventé (`--include-bc`, etc.).
- **Lignes `implement-feature-*` = chemin du `.feature` obligatoire dans la commande.** Ex. `/task-implement-feature-auto-back docs/bdd/<projet>/<bc>/<slug>.feature`. Sans ce chemin, l'agent fork part à l'aveugle et demande l'argument manquant. La colonne `Commande` reste l'invocation exacte — pas de colonne `Référence` séparée.

### Exemple

```markdown
# Progression <Projet>

> Source : docs/story-mapping/<projet>/story-map.md
> Mode TDD : autonome / step-by-step

## Séquence

| # | Étape | Commande | Statut |
|---|-------|----------|--------|
| 1 | Scaffold backend foundation | `/task-scaffold-back` | ✅ fait |
| 2a | Scaffold BC Identite | `/task-scaffold-back Identite` | ⏳ prochaine |
| 2b | Scaffold agrégat Utilisateur | `/task-scaffold-back Identite Utilisateur` | ⏸ à faire |
| 3 | US-1 backend — InscrireUtilisateur (TDD autonome) | `/task-implement-feature-auto-back docs/bdd/<projet>/identite/inscrire-utilisateur.feature` | ⏸ à faire |

## Bilans

### Étape 1 — <titre> (YYYY-MM-DD)

- livrable principal
- point de vigilance
- lien vers docs ou commit
```

## Règles

- **Ne jamais relancer une étape déjà `✅ fait`** sans demande explicite de l'utilisateur.
- **Une seule étape par invocation** — pas d'enchaînement automatique de plusieurs étapes.
- **Le fichier `progression.md` est la source unique de vérité** — pas de rapport séparé dupliqué ailleurs.
- Si la commande déléguée produit son propre rapport (ex. `docs/scaffold-*.md`), supprimer la duplication : le bilan vit dans `progression.md`. Voir `backend/CLAUDE.md` § « Rapports d'exécution — pas de duplication ».
