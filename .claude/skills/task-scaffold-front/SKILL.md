---
name: task-scaffold-front
description: Scaffold frontend infrastructure — project structure, services, test harness (bUnit + Playwright)
user-invocable: true
argument-hint: "[feature area or description]"
context: fork
agent: scaffold-front
---

# /task-scaffold-front -> scaffold-front agent

Delegates to the `scaffold-front` agent.

## Usage

```
/scaffold-front
/scaffold-front <feature area or description>
```

## Examples

```
/scaffold-front
/scaffold-front la page de gestion des parties
/scaffold-front ajouter le service API pour les utilisateurs
```

## What this triggers

1. **DIAGNOSTIC** — inventory of what exists vs what is missing + user gate
2. **PROJECT STRUCTURE** — directories, shared config, layout
3. **SERVICE LAYER** — API clients, DI registration, models
4. **TEST HARNESS** — bUnit project, Playwright project, test fakes, smoke test

## Constraints

- Never writes business logic — only plumbing and structure
- Never creates or modifies backend code
- All existing tests must remain green throughout

## Suggested follow-up

- `/task-scaffold-back` — backend infrastructure scaffolding
- `/task-implement-feature-front` — TDD Presenter implementation
