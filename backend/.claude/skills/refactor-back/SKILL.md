---
name: refactor-back
description: Refactor existing code without changing behavior (iso-functional)
user-invocable: true
argument-hint: "<scope or file(s) to refactor>"
context: fork
agent: refactor
---

# /refactor-back -> refactor agent

Delegates to the `refactor` agent.

## Usage

```
/refactor-back <scope or file(s) to refactor>
```

## Examples

```
/refactor-back src/Domain/Partie.cs
/refactor-back la couche application du module Parties
/refactor-back extraire les Value Objects primitifs dans le domaine
```

## What this triggers

1. **ANALYSE** — produces `docs/refactor-<scope>-<date>.md` + user gate
2. **REFACTOR** — baby steps, tests after each step + user gate
3. **REPORT** — summary of all changes made

## Constraints

- No tests will be created, modified, or deleted
- All existing tests must remain green throughout
