---
description: "ASP.NET Core Identity as infrastructure adapter — optional recipe for user management bounded context"
alwaysApply: false
globs: ["**/Identity/**/*.cs", "**/Infrastructure/**/*User*.cs", "**/Infrastructure/**/*Password*.cs"]
---

# Rule: ASP.NET Core Identity as Infrastructure Adapter

> **This rule is an optional recipe.** It applies when the project includes a user management / authentication bounded context. If your project does not need user management, this rule can be ignored.

## Core Principle

ASP.NET Core Identity is an **infrastructure detail**. It lives exclusively in the `Infrastructure` and `Api` layers. The Domain and Application layers never reference Identity types.

The domain `Utilisateur` aggregate remains the **single source of truth** for business logic (inscription, confirmation, statut). Identity handles the technical concerns: password hashing, claims, roles, lockout, 2FA.

## Architecture

```
Domain                          Infrastructure
┌─────────────────────┐         ┌──────────────────────────┐
│ Utilisateur          │         │ ApplicationUser          │
│  (aggregate root)    │  ←───→  │  : IdentityUser<Guid>    │
│  - business logic    │  map    │  - persistence           │
│  - domain events     │         │  - password hash         │
│  - MotDePasseHash    │         │  - claims / roles        │
└─────────────────────┘         └──────────────────────────┘
```

## Password Handling

### Flow

1. **Validation** — `MotDePasse.Creer(raw)` validates business rules (min 8 chars, 1 uppercase, 1 digit). Transient value object — never stored.
2. **Hashing** — `IPasswordHasher.Hash(raw)` produces a `MotDePasseHash` (Value Object). Port defined in `Application/Ports`, implementation uses Identity's `PasswordHasher<T>`.
3. **Storage** — `MotDePasseHash` wraps the opaque hash string. This is what `Utilisateur` stores.
4. **Verification** — `IPasswordHasher.Verifier(raw, hash)` takes a `MotDePasseHash` and delegates to Identity.

### Rules

- **Never store raw passwords** in the domain. `Utilisateur` holds `MotDePasseHash`, not `MotDePasse`.
- **`MotDePasse`** is a validation-only value object. Discarded after the handler uses it.
- **`MotDePasseHash`** is an opaque storage value object. `Reconstituer(string)` for persistence.
- The **`IPasswordHasher`** port returns `MotDePasseHash` (Value Object), not a raw string.

## Persistence Model

```csharp
// Infrastructure
public sealed class ApplicationUser : IdentityUser<Guid>
{
    public string Statut { get; set; } = string.Empty;
    public string TokenDeConfirmation { get; set; } = string.Empty;
    public DateTimeOffset TokenExpireA { get; set; }

    public Utilisateur ToDomain() => ...;
    public static ApplicationUser FromDomain(Utilisateur u) => ...;
}
```

## DbContext

`AppDbContext` inherits from `IdentityDbContext<ApplicationUser, IdentityRole<Guid>, Guid>`.

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Identity user model | `ApplicationUser` | `public sealed class ApplicationUser : IdentityUser<Guid>` |
| Password hasher port | `IPasswordHasher` | Defined in `Application/Ports` |
| Password hasher impl | `IdentityPasswordHasher` | Uses `PasswordHasher<ApplicationUser>` |
| Hash value object | `MotDePasseHash` | `readonly record struct`, `Reconstituer(string)` |
| Validation value object | `MotDePasse` | `Creer(string)` validates rules, transient use only |


---
