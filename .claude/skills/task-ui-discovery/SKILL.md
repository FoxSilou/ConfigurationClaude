---
name: task-ui-discovery
description: UI Discovery workshop — screen inventory, user flows, and Presenter specs from event-storming
user-invocable: true
argument-hint: "<event-storming document> [bounded context name]"
context: fork
agent: ui-discovery
---

# /task-ui-discovery -> ui-discovery agent

Delegates to the `ui-discovery` agent.

## Usage

```
/task-ui-discovery <event-storming document>
/task-ui-discovery <event-storming document> <bounded context name>
```

## Examples

```
/task-ui-discovery docs/event-storming/imperium-rex/event-storming-imperium-rex-2026-04-02.md
/task-ui-discovery docs/event-storming/imperium-rex/event-storming-imperium-rex-2026-04-02.md Game Management
```

## What this triggers

1. **Phase 1 -- Inventaire des ecrans** — screens grouped by Actor from Read Models and Commands
2. **Phase 2 -- Flux utilisateur** — screen-to-screen navigation (success + error paths)
3. **Phase 3 -- Specs Presenter** — state, visibility, actions, gateway contract, ordered TDD test list
4. **Validation gates** — user confirms each phase before proceeding
5. **Output**:
   - `docs/ui-discovery/<domain>/<bc>/ui-discovery-<bc>-<date>.md`

## Suggested follow-up

Once all specs are ready (BDD + UI Discovery), run `/task-story-mapping` to organize tasks into ordered user stories.
Then `/task-scaffold` to wire infrastructure, and implement stories in order with `/task-implement-feature-front` for TDD.
