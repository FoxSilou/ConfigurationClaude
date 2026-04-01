---
description: "Ports (repository interfaces + service interfaces), adapter implementations, Value Objects in port signatures"
globs: ["**/Ports/**/*.cs", "**/Domain/**/*.cs", "**/Application/**/*.cs", "**/Infrastructure/**/*.cs"]
---

# Rule: Ports, Repositories & Services

## Repositories

Repositories handle **aggregates only** — no repositories for simple entities or value objects.

### Interface (Port) — defined in `Domain/Ports`

```csharp
public interface I<AggregateName>Repository
{
    Task<Partie?> ObtenirParIdAsync(PartieId id, CancellationToken ct = default);
    Task AjouterAsync(Partie partie, CancellationToken ct = default);
    Task MettreAJourAsync(Partie partie, CancellationToken ct = default);
}
```

### Implementation (Adapter) — defined in `Infrastructure`

| Storage strategy | Prefix | Example |
|---|---|---|
| Event Sourcing | `EventSourced` | `EventSourcedPartieRepository` |
| In-memory (tests/stubs) | `InMemory` | `InMemoryPartieRepository` |
| Relational DB (EF Core) | `EfCore` | `EfCorePartieRepository` |
| Document DB | `Mongo` | `MongoPartieRepository` |

### Rules

- Repository interfaces are defined in **`Domain/Ports`**.
- Repository implementations are defined in **`Infrastructure`**.
- One repository per aggregate — never share a repository between aggregates.
- Method names follow the **ubiquitous language in French**: `ObtenirParIdAsync`, `AjouterAsync`, `MettreAJourAsync`, `SupprimerAsync`, `ListerAsync`.
- Never expose `IQueryable<T>` from a Write repository — queries go through the Read side.

---

## Services (Ports & Adapters)

### Interface (Port) — defined in `Application/Ports`

```csharp
public interface IPdfGenerator { ... }
public interface IEmailSender { ... }
public interface IPaymentGateway { ... }
```

### Implementation (Adapter) — defined in `Infrastructure`

```csharp
public sealed class SyncfusionPdfGenerator : IPdfGenerator { ... }
public sealed class SendGridEmailSender : IEmailSender { ... }
public sealed class StripePaymentGateway : IPaymentGateway { ... }
```

### Rules

- Service interfaces are defined in **`Application/Ports`**.
- Service implementations are defined in **`Infrastructure`**.
- Interface names describe **what** the service does (functional, technology-agnostic).
- Implementation names describe **how** it is done (technology or provider first).
- Never leak provider-specific types into `Application` or `Domain`.

### ⚠️ CRITICAL RULE — Ports use Value Objects, not primitives

Application port signatures must use **domain Value Objects** rather than raw primitives. This ensures only validated values flow between layers.

```csharp
// ✅ CORRECT — uses Value Objects
public interface IPasswordHasher
{
    MotDePasseHash Hash(string motDePasseBrut);
    bool Verifier(string motDePasseBrut, MotDePasseHash hash);
}

public interface IEmailSender
{
    Task EnvoyerEmailDeConfirmationAsync(
        AdresseEmail destinataire,
        TokenDeConfirmation token,
        CancellationToken ct = default);
}

// ❌ FORBIDDEN — primitives in port signatures
public interface IPasswordHasher
{
    string Hash(string motDePasseBrut); // string instead of MotDePasseHash
}
```

## Naming Conventions

| Element | Language | Convention | Example |
|---|---|---|---|
| Repository interface | English (technical) | `I<AggregateName>Repository` | `IPartieRepository` |
| Repository implementation | English (technical) | `<Technology><AggregateName>Repository` | `EfCorePartieRepository` |
| Repository methods | French (domain) | French verb + complement | `ObtenirParIdAsync`, `AjouterAsync` |
| Service interface | English (technical) | `I<FunctionalRole>` | `IPdfGenerator`, `IEmailSender` |
| Service implementation | English (technical) | `<Technology><FunctionalRole>` | `SyncfusionPdfGenerator` |


---
