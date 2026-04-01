---
description: Implement a new feature using TDD step-by-step (user gate after each RED, GREEN, and REFACTOR)
---

# /implement-feature-back → implement-feature agent (STEP-BY-STEP mode)

Delegates to the `implement-feature` agent in **STEP-BY-STEP** mode.

In this mode, the user validates each step:
- **RED gate**: review the test before writing production code
- **GREEN gate**: review the implementation before refactoring
- **REFACTOR gate**: select which refactoring actions to apply

## Usage

```
/implement-feature <feature description or .feature file>
```

## Examples

```
/implement-feature-back docs/features/inscription.feature
/implement-feature-back créer une partie de jeu avec un nom et une date de début
```

## What this triggers

1. **ANALYSE** — produces `docs/<feature-name>.md` + user gate
2. **TDD STEP-BY-STEP** — RED → ⛔ → GREEN → ⛔ → REFACTOR → ⛔ per test
3. **E2E** — critical paths confirmed by user

## See also

- `/implement-feature-auto` — autonomous mode with a single gate at the end
