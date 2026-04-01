---
description: BDD workshop — Example Mapping + Gherkin feature files from domain knowledge
---

# /bdd-workshop → bdd-workshop agent

Delegates to the `bdd-workshop` agent.

## Usage

```
/bdd-workshop <feature or event-storming document>
```

## Examples

```
/bdd-workshop docs/event-storming-tournois-2026-03-27.md
/bdd-workshop créer une partie de tournoi avec un nombre maximum de joueurs
```

## What this triggers

1. **Mode detection** — document or interactive
2. **Three Amigos session** — rules, examples, questions
3. **Validation gate** — resolve open questions before output
4. **Outputs**:
   - `docs/example-mapping-<feature>-<date>.md`
   - `docs/features/<feature-name>.feature`

## Suggested follow-up

Run `/implement-feature` with the produced `.feature` file as input.
