---
name: task-implement-feature-front
description: Implement a frontend feature using TDD on Presenters (step-by-step with user gates)
user-invocable: true
argument-hint: "<ui-discovery spec or Presenter description>"
context: fork
agent: implement-feature-front
---

# /task-implement-feature-front -> implement-feature-front agent

Delegates to the `implement-feature-front` agent in **step-by-step** mode.

## Usage

```
/task-implement-feature-front <ui-discovery spec or Presenter description>
/task-implement-feature-front <path to spec> mode autonome
```

## Examples

```
/task-implement-feature-front docs/ui-discovery/imperium-rex/game-management/ui-discovery-game-management-2026-04-05.md
/task-implement-feature-front le Presenter pour l'ecran Rejoindre une partie
/task-implement-feature-front docs/ui-discovery/imperium-rex/game-management/ui-discovery-game-management-2026-04-05.md mode autonome
```

## What this triggers

1. **PHASE 0 -- ANALYSE** — confirm Presenter spec, test list, backend dependencies
2. **PHASE 1 -- TDD PRESENTER** — RED/GREEN/REFACTOR on each test (step-by-step or autonome)
3. **PHASE 2 -- CABLAGE COMPOSANT** — wire .razor page to Presenter (binding only)
4. **PHASE 3 -- GATEWAY** — implement HTTP Gateway against backend endpoints
5. **Outputs**:
   - `docs/front/<feature-name>.md` — analysis document
   - `UI.Domain/Presenters/<Feature>/` — Presenter class
   - `UI.Domain/Ports/` — Gateway interface
   - `UI.Domain.Tests/Presenters/` — Presenter tests + Fake Gateway
   - `UI.Infrastructure/Gateways/` — HTTP Gateway
   - `UI.Blazor/Pages/` — .razor component

## Constraints

- Never writes backend code
- Requires UI Discovery spec or equivalent Presenter description
- Backend endpoints must exist for Phase 3 (Gateway implementation)

## See also

- `/task-ui-discovery` — produces the Presenter specs consumed by this command
- `/task-scaffold-front` — scaffolds infrastructure (run first if projects don't exist)
- `/task-implement-feature-back` — backend counterpart
