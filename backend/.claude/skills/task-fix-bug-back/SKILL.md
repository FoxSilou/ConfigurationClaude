---
name: task-fix-bug-back
description: Fix a bug using a test-first approach — E2E reproduction before any fix
user-invocable: true
argument-hint: "<bug description>"
context: fork
agent: fix-bug
---

# /task-fix-bug-back -> fix-bug agent

Delegates to the `fix-bug` agent.

## Usage

```
/fix-bug-back <bug description>
```

## Examples

```
/fix-bug-back créer une partie avec un nom vide retourne 200 au lieu de 400
/fix-bug-back le score d'un joueur n'est pas mis à jour après une partie terminée
```

## What this triggers

1. **ANALYSE** — produces `docs/bug-<description>-<date>.md` + user gate
2. **REPRODUCE** — E2E test that fails (proves the bug) + user gate
3. **FIX** — minimal correction, unit tests added if needed
4. **REPORT** — summary of changes, confirmation no existing tests were modified

## Constraints

- No existing tests will be modified
- Production code is never touched before a failing test exists
