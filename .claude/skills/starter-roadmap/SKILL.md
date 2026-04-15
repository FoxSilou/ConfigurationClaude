---
name: starter-roadmap
description: Use when bootstrapping a new project from scratch, when the user asks "par où commencer ?", or when the factory sequence (workshop → scaffold → implement) needs to be recalled to order the next steps.
user-invocable: false
---

# Skill: Starter Roadmap (Factory)

Séquence canonique pour scaffolder un nouveau projet .NET backend + Blazor frontend à partir de cette factory.

## Phase 1 — Discovery

1. `/task-event-storming` — découverte domaine (Big Picture → Process → Software Design).
2. `/task-bdd-workshop` — Example Mapping + `.feature` Gherkin par scénario.
3. `/task-ui-discovery` — écrans, user flows, specs Presenter.
4. `/task-story-mapping` — roadmap MVP ordonnée en user stories verticales.

## Phase 2 — Scaffold backend

5. `/task-scaffold-back` (sans argument) — foundation Mode 1 (`Shared.Write/Read`, Api, E2E harness).
6. `/task-scaffold-back <BC>` — Mode 2 par bounded context (persistence, ports, DI, fakes E2E).
7. `/task-scaffold-back <BC> <Aggregate>` — Mode 3 par agrégat (typed Id, events, repository, command/query, endpoints).

## Phase 3 — Scaffold frontend

8. `/task-scaffold-front` — structure projet Blazor hexagonal + client NSwag + harness bUnit/Playwright (requiert `backend/Api.json`).

## Phase 4 — Implémentation (dans l'ordre des stories)

9. `/task-implement-feature-back` (step-by-step) ou `/task-implement-feature-auto-back` (autonome) — TDD domaine.
10. `/task-implement-feature-front` — TDD Presenter.

## Phase 5 — Maintenance

11. `/task-fix-bug-back` — correctifs test-first.
12. `/task-refactor-back` — refactoring iso-fonctionnel.
13. `/task-resume` — reprise post-`/clear` via `docs/story-mapping/<projet>/progression.md`.

## Prérequis inter-phases

- Mode 2 requiert Mode 1 ; Mode 3 requiert Mode 2 du BC.
- `/task-implement-feature-back` requiert : BC scaffoldé + `.feature` écrit.
- `/task-implement-feature-front` requiert : backend de l'US livré (si nouvel endpoint) + spec Presenter UI Discovery.
- Frontend : rebuild backend avant rebuild frontend si `Api.json` a changé.
