# CLAUDE.md — Frontend

This is the frontend solution (Blazor / MAUI). It communicates with the backend via HTTP APIs.

---

## Tech Stack

- **Framework**: Blazor (WebAssembly or Server) / .NET MAUI (depending on context)
- **Tests**: bUnit (component testing), Playwright for .NET (E2E UI testing)
- **Assertions**: FluentAssertions
- **API client**: NSwag (typed HTTP client generated from backend `Api.json` OpenAPI spec — URLs and DTOs are synchronized at build time)
- **Conventions**: Same C# conventions as backend (see workspace CLAUDE.md)

---

## Architecture

The frontend follows a hexagonal architecture:

```
src/
├── ImperiumRex.UI.Blazor/          ← Composition root + Razor pages/components (UI Kit wrappers)
├── ImperiumRex.UI.Domain/          ← Presenters (pure C#) + Ports (gateway interfaces)
│   ├── Presenters/
│   └── Ports/
└── ImperiumRex.UI.Infrastructure/  ← Gateway implementations (HTTP adapters)
    └── Gateways/
```

- **Pages/Components** — thin Razor shells binding to Presenters (wrapped via UI Kit, see skill `blazor-ui-kit`)
- **Presenters** — pure C# classes handling UI logic, no Blazor dependency (see skill `blazor-hexagonal`)
- **Ports** — gateway interfaces defined in Domain (`IXxxGateway`)
- **Gateways** — HTTP implementations of ports, in Infrastructure

---

## Testing Strategy

- **bUnit** is the default for component logic, state, and data binding bugs.
- **Playwright** is reserved for bugs reported through the UI where the interaction path itself matters.
- Never use Playwright when bUnit can reproduce the bug.

→ See skill: `frontend-testing`
→ Hexagonal frontend (Presenters): see skill `blazor-hexagonal`
→ UI Kit (wrappers Radzen): see skill `blazor-ui-kit`

## Pattern Rules (auto-loaded)

@.claude/rules/blazor-hexagonal-frontend.md
@.claude/rules/encapsulation-composants-ui.md

## Slash Commands

| Command | Description |
|---|---|
| `/task-scaffold-front` | Frontend project structure + test harness (bUnit + Playwright) |
| `/task-implement-feature-front` | TDD Presenter step-by-step (or autonome) |

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
