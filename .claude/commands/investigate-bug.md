---
description: Investigate a UI-reported bug across frontend and backend solutions before fixing
---

# /investigate-bug → investigate-bug agent

Delegates to the `investigate-bug` agent.

## Usage

```
/investigate-bug <bug description and reproduction steps>
```

With screenshot attached in Claude Code:
```
/investigate-bug <description> [+ attach screenshot]
```

## Examples

```
/investigate-bug le score d'un joueur n'est pas mis à jour après la fin d'une partie
/investigate-bug la liste des parties s'affiche vide alors qu'il y en a en base [+ screenshot]
/investigate-bug cliquer sur "Valider" ne fait rien et aucune erreur n'est affichée
```

## Prerequisites

Run from the workspace root containing both repos:
```
workspace/
├── frontend/
└── backend/
```

## What this triggers

1. **Parse report** — description + screenshot analysis if provided
2. **Frontend investigation** — trace data flow, check API contract
3. **Backend investigation** — trace request flow, check domain logic
4. **Diagnosis gate** — produces `docs/investigation-<...>.md` + user validation
5. **Handoff** — precise instructions for `fix-bug` in the right repo(s)

## Suggested follow-up

```
/fix-bug context:docs/investigation-<...>.md <root cause description>
```
