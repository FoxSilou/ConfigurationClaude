# CLAUDE.md — Frontend

This is the frontend solution (Blazor / MAUI). It communicates with the backend via HTTP APIs.

---

## Tech Stack

- **Framework**: Blazor (WebAssembly or Server) / .NET MAUI (depending on context)
- **Tests**: bUnit (component testing), Playwright for .NET (E2E UI testing)
- **Assertions**: FluentAssertions
- **Conventions**: Same C# conventions as backend (see workspace CLAUDE.md)

---

## Architecture

The frontend follows a clean separation between:

- **Pages** — top-level routable components
- **Components** — reusable UI building blocks (wrapped via UI Kit, see skill `blazor-ui-kit`)
- **Presenters** — pure C# classes handling UI logic (see skill `blazor-hexagonal`)
- **Services** — injected services for API communication and state management
- **Models** — DTOs matching the backend API contracts

---

## Testing Strategy

- **bUnit** is the default for component logic, state, and data binding bugs.
- **Playwright** is reserved for bugs reported through the UI where the interaction path itself matters.
- Never use Playwright when bUnit can reproduce the bug.

→ See skill: `frontend-testing`
→ Hexagonal frontend (Presenters): see skill `blazor-hexagonal`
→ UI Kit (wrappers Radzen): see skill `blazor-ui-kit`

## Slash Commands

| Command | Description |
|---|---|
| `/task-scaffold-front` | Frontend project structure + test harness (bUnit + Playwright) |

## Expected Behavior

### Always

- Use `data-testid` attributes for test selectors — never CSS classes or text content.
- Keep components thin — business logic belongs in services or the backend.
- Use dependency injection for all services.
- Follow the same naming conventions as the backend (French ubiquitous language for domain concepts).

### Never

- Put business logic in components.
- Use CSS classes or text content as Playwright selectors.
- Skip testing a component because "it's just UI".
