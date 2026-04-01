---
name: backend-conventions
description: >
  Full backend coding conventions, naming rules, and behavioral checklist.
  Use when writing, reviewing, or modifying C# backend code — especially
  when creating new domain types, commands, queries, repositories, or services.
  Covers: naming table (French ubiquitous language), C# style rules,
  Always/Never behavioral checklist, error handling strategy, and test double conventions.
user-invocable: false
---

# Skill: Backend Conventions

## Naming Conventions

Domain code follows the **ubiquitous language in French**. Technical/infrastructure code is in English.

| Element | Convention | Example |
|---|---|---|
| Command | French infinitive verb + noun, no suffix | `CreerPartie`, `AnnulerCommande` |
| Query | French infinitive verb + noun, no suffix | `ObtenirPartie`, `ListerJoueurs` |
| Nested handler | Always `Handler` | `public sealed class Handler(...)` |
| Domain event | French past participle + noun, no suffix | `PartieCree`, `CommandeAnnulee` |
| DTO | French noun + `Dto` suffix | `PartieDto`, `JoueurDto` |
| Repository interface | `I` + aggregate name + `Repository` | `IPartieRepository` |
| Repository implementation | Technology + aggregate name + `Repository` | `EfCorePartieRepository`, `InMemoryPartieRepository` |
| Repository methods | French verb + complement | `ObtenirParIdAsync`, `AjouterAsync` |
| Service interface | `I` + functional role (English) | `IPdfGenerator`, `IEmailSender` |
| Service implementation | Technology/provider + functional role | `SyncfusionPdfGenerator`, `SendGridEmailSender` |
| Typed Id | Entity name + `Id` | `PartieId`, `JoueurId` |
| Entity factory (business) | French verb | `Creer`, `Inscrire`, `Demarrer` |
| Entity factory (persistence) | Always `Reconstituer` | `Partie.Reconstituer(...)` |
| Value Object factory (business) | French verb | `Creer`, `Definir` |
| Value Object factory (persistence) | Always `Reconstituer` | `NomDePartie.Reconstituer(...)` |
| Id factory (new) | `Nouveau()` | `PartieId.Nouveau()` |
| Id factory (from primitive) | `Reconstituer(Guid)` | `PartieId.Reconstituer(guid)` |

---

## C# Code Conventions

- **Naming**: PascalCase for everything public, `_camelCase` for private fields.
- **No abbreviations** in variable or method names.
- **`sealed`** on classes that must not be inherited.
- **`required`** on mandatory properties.
- Prefer `IReadOnlyCollection<T>` over `List<T>` in public signatures.
- Use **primary constructors** where appropriate.
- Enable `<Nullable>enable</Nullable>` and `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>`.
- **`DateTimeOffset` over `DateTime`**: always use `DateTimeOffset`, never `DateTime`.
- **`TimeProvider` for time abstraction**: never call `DateTimeOffset.UtcNow` or any system clock directly. Use `TimeProvider` injected via DI. In tests, use `FakeTimeProvider`.
- **Domain code is in French** (ubiquitous language). Technical/infrastructure code is in English.
- **No `null` in the domain**: use the `Result<T>` pattern or throw domain exceptions.
- **Test doubles**: Fakes and Stubs only — no Mocks (no Moq, no NSubstitute in domain/application tests).
- **Test double naming**: Fakes use prefix `Fake` (`FakeEmailSender`), Stubs use prefix `Stubbed` (`StubbedHorloge`). In-memory repository fakes use `InMemory` prefix (`InMemoryUtilisateurRepository`).

---

## Error Handling

- **Business exceptions** are thrown in the domain (`DomainException`, `NotFoundException`...).
- A global middleware in `Api` catches exceptions and returns standardized responses (Problem Details — RFC 7807).
- Never let unwrapped infrastructure exceptions bubble up.
- **No `null` in the domain**: use the `Result<T>` pattern or throw domain exceptions.

→ See rule: `error-handling.md`

---

## Expected Claude Code Behavior

### Always

- Respect layer separation: never put business logic in `Api` or `Infrastructure`.
- Create tests alongside implementation (TDD). → See skill: `tdd-workflow`
- Propose Domain Events when a state change is significant.
- Use interfaces (ports) for any external dependency.
- Document non-obvious architectural decisions with an `// ADR:` comment.
- Respect strict CQRS separation: Read and Write are independent stacks.
- Place invariants in the private constructor, not in factory methods.
- Use `DateTimeOffset` everywhere, never `DateTime`. Use `TimeProvider` for time.
- Application ports use Value Objects, never raw primitives.
- MediatR must never appear in Domain or Application — only in Infrastructure.

### Never

- Reference `Infrastructure` from `Domain` or `Application`.
- Use mutable `static` or the Singleton pattern unless explicitly justified.
- Expose domain entities directly in API responses (always map to DTOs).
- Ignore a compilation warning.
- Generate code without an associated test if the change touches Domain or Application.
- Reference MediatR (`using MediatR`, `IRequest`, `IRequestHandler`, `ISender`, `IMediator`) in Domain or Application.
- Use `DateTime` — always `DateTimeOffset`.
- Call `DateTimeOffset.UtcNow` or any system clock directly — always via `TimeProvider`.
- Put invariants in factory methods — they belong to the private constructor.
- Use primitives in port signatures when a Value Object exists for that concept.

### Before Coding

1. Identify the target layer.
2. Check if a port (interface) already exists or needs to be created.
3. Write the test first.
4. Implement the minimum to pass the test.
5. Refactor if necessary.
