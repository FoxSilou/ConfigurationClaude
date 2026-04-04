---
name: task-event-storming
description: Event Storming workshop for domain discovery — produces markdown + Excalidraw board
user-invocable: true
argument-hint: "<domain or document>"
context: fork
agent: event-storming
---

# /task-event-storming -> event-storming agent

Delegates to the `event-storming` agent.

## Usage

```
/task-event-storming <domain or document>
```

## Examples

```
/task-event-storming je veux créer une application de gestion de tournois de jeux de société
/task-event-storming [paste document or fuzzy rules here]
```

## What this triggers

1. **Mode detection** — document or interactive
2. **Domain exploration** — events, commands, aggregates, policies, bounded contexts, hotspots
3. **Validation gate** — review before output
4. **Outputs**:
   - `docs/event-storming/event-storming-<domain>-<date>.md` — structured markdown
   - `docs/event-storming/event-storming-<domain>-<date>-aggregates.excalidraw` — aggregate-centric view (blocks CMD->AGG->EVT, policies below, no arrows)
   - `docs/event-storming/event-storming-<domain>-<date>-flows.excalidraw` — flow view (use-case chains left->right, curved arrows, forks)

## Suggested follow-up

Run `/task-bdd-workshop` on the produced document to formalize scenarios.
