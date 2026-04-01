---
description: Scaffold infrastructure for backend, frontend, or both — orchestrates scaffold-back and scaffold-front
---

# /scaffold → Global scaffolding orchestrator

Orchestrates the `scaffold-back` and `scaffold-front` agents. Asks the user which scope to scaffold before delegating.

## Usage

```
/scaffold
/scaffold <bounded context or feature area>
```

## Behavior

When invoked, ask the user:

> *"Que souhaitez-vous scaffolder ?"*
> 1. **Backend uniquement** — lance `/scaffold-back`
> 2. **Frontend uniquement** — lance `/scaffold-front`
> 3. **Les deux** — lance `/scaffold-back` d'abord, puis `/scaffold-front` après validation

Then, for backend, ask the scope:

> *"Quel type de scaffolding backend ?"*
> 1. **Général** — fondation partagée (SharedKernel, messaging, API shell, E2E harness)
> 2. **Bounded context** — infrastructure spécifique à un BC (préciser le nom)

### Sequencing rules

- **General scaffolding must be done before any BC scaffolding** — the shared foundation is a prerequisite.
- **Backend before frontend** when both are selected — the frontend depends on backend API contracts.
- Each sub-scaffold has its own diagnostic, phases, and gates — this orchestrator does not bypass them.
- If only one side is selected, delegate directly to the appropriate agent without additional ceremony.

## Examples

```
/scaffold
→ "Que souhaitez-vous scaffolder ? Backend, Frontend, ou les deux ?"
→ User: "Backend uniquement"
→ "Quel type ? Général ou Bounded context ?"
→ User: "Général"
→ Runs scaffold-back (general mode)

/scaffold Identite
→ "Que souhaitez-vous scaffolder ? Backend, Frontend, ou les deux ?"
→ User: "Les deux"
→ Runs scaffold-back for Identite, then scaffold-front

/scaffold
→ User: "Backend uniquement, général"
→ Runs scaffold-back (general mode)
```

## See also

- `/scaffold-back` — backend scaffolding (general foundation or BC-specific)
- `/scaffold-front` — frontend scaffolding only (project structure, services, test harness)
