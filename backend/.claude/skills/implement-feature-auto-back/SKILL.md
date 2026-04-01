---
name: implement-feature-auto-back
description: Implement a new feature using TDD autonomously (single user gate at the end)
user-invocable: true
argument-hint: "<feature description or .feature file>"
context: fork
agent: implement-feature
---

# /implement-feature-auto-back -> implement-feature agent (AUTONOME mode)

Delegates to the `implement-feature` agent in **AUTONOME** mode.

In this mode, the agent runs all TDD cycles (RED -> GREEN -> REFACTOR) without interruption. A single user gate at the end presents a complete summary for review.

Use this mode when:
- You trust the conventions and want faster execution
- The feature is well-specified and straightforward
- You want to review the result as a whole rather than step-by-step

## Usage

```
/implement-feature-auto-back <feature description or .feature file>
```

## Examples

```
/implement-feature-auto-back docs/features/confirmation-email.feature
/implement-feature-auto-back docs/features/connexion.feature
```

## What this triggers

1. **ANALYSE** — produces `docs/<feature-name>.md` + user gate
2. **TDD AUTONOME** — full cycle for all tests, no intermediate gates
3. **FINAL GATE** — detailed summary of everything produced (tests, code, refactoring decisions)
4. **E2E** — critical paths confirmed by user

## See also

- `/implement-feature-back` — step-by-step mode with user gates after each RED, GREEN, and REFACTOR
