---
name: task-bdd-workshop
description: BDD workshop — Example Mapping + Gherkin feature files from domain knowledge
user-invocable: true
argument-hint: "<feature or event-storming document>"
context: fork
agent: bdd-workshop
---

# /task-bdd-workshop -> bdd-workshop agent

Delegates to the `bdd-workshop` agent.

## Usage

```
/task-bdd-workshop <feature or event-storming document>
```

## Examples

```
/task-bdd-workshop docs/event-storming-tournois-2026-03-27.md
/task-bdd-workshop créer une partie de tournoi avec un nombre maximum de joueurs
```

## What this triggers

1. **Mode detection** — document or interactive
2. **Three Amigos session** — rules, examples, questions
3. **Validation gate** — resolve open questions before output
4. **Outputs**:
   - `docs/example-mapping-<feature>-<date>.md`
   - `docs/features/<feature-name>.feature`

## Suggested follow-up

Run `/task-implement-feature-back` with the produced `.feature` file as input.
