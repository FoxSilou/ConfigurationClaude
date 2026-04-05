---
name: task-story-mapping
description: Story Mapping — ordered MVP roadmap from BDD + UI Discovery outputs
user-invocable: true
argument-hint: "<domain name> or <bdd-dir> <ui-discovery-dir>"
context: fork
agent: story-mapping
---

# /task-story-mapping -> story-mapping agent

Delegates to the `story-mapping` agent.

## Usage

```
/task-story-mapping <domain name>
/task-story-mapping <bdd-docs-dir> <ui-discovery-docs-dir>
```

## Examples

```
/task-story-mapping imperium-rex
/task-story-mapping docs/bdd/imperium-rex docs/ui-discovery/imperium-rex
```

## What this triggers

1. **Phase 1 -- Inventaire des taches** — scan all `.feature` files and UI Discovery Presenter specs, present consolidated inventory
2. **Phase 2 -- Regroupement en User Stories** — group tasks into vertical slices (one story = one user capability = backend + frontend)
3. **Phase 3 -- Ordonnancement MVP** — order stories by incremental value, walking skeleton first
4. **Phase 4 -- Generation** — produce the story map document with implementation commands
5. **Validation gates** — user confirms each phase before proceeding
6. **Output**:
   - `docs/story-mapping/<domain>/story-map-<domain>-<date>.md`

## Suggested follow-up

Run `/task-scaffold` to wire infrastructure, then implement stories in order with `/task-implement-feature-back` and `/task-implement-feature-front`.
