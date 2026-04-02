---
description: "Error handling strategy — domain exceptions vs Result<T>, Problem Details mapping"
globs: ["**/Domain/**/*.cs", "**/Application/**/*.cs", "**/Api/**/*.cs", "**/Middleware/**/*.cs"]
---

# Rule: Error Handling

## Strategy

The project uses **two complementary approaches** for error handling:

- **Domain exceptions** for invariant violations and truly exceptional situations (entity not found, aggregate corruption, concurrency conflicts).
- **`Result<T>` pattern** for expected business outcomes that are not exceptional (validation failures, business rule rejections where the caller is expected to handle the outcome).

### When to use which

| Situation | Approach | Example |
|---|---|---|
| Invariant violation in constructor | Throw `DomainException` | Empty name, negative amount |
| Entity not found | Throw `NotFoundException` | `ObtenirParIdAsync` returns null |
| Business rule with expected failure | Return `Result<T>` | "Cannot join: game is full" |
| Concurrency conflict | Throw `ConcurrencyException` | Optimistic locking failure |
| Infrastructure failure | Let it propagate (caught by middleware) | Database timeout, network error |

## Domain Exceptions

Domain exceptions inherit from `DomainException` (defined in Shared.Write.Domain):

```csharp
// Shared.Write.Domain
public class DomainException : Exception
{
    public DomainException(string message) : base(message) { }
}

public class NotFoundException : DomainException
{
    public NotFoundException(string message) : base(message) { }
}
```

Thrown in domain code (constructors, behavior methods):

```csharp
private NomDePartie(string valeur)
{
    if (string.IsNullOrWhiteSpace(valeur))
        throw new DomainException("Le nom de la partie ne peut pas être vide.");
    Valeur = valeur.Trim();
}
```

## Result Pattern (optional, for expected failures)

When a use case has expected failure modes that callers should handle explicitly:

```csharp
public readonly record struct Result<T>
{
    public T? Value { get; }
    public string? Error { get; }
    public bool IsSuccess => Error is null;

    private Result(T value) { Value = value; Error = null; }
    private Result(string error) { Value = default; Error = error; }

    public static Result<T> Success(T value) => new(value);
    public static Result<T> Failure(string error) => new(error);
}
```

## API Layer — Problem Details (RFC 7807)

A global middleware in `Api` catches exceptions and returns standardized Problem Details responses:

```csharp
// Mapping
DomainException    → 400 Bad Request
NotFoundException  → 404 Not Found
ConcurrencyException → 409 Conflict
Unhandled          → 500 Internal Server Error (no details exposed)
```

### Rules

- Never let unwrapped infrastructure exceptions bubble up to the client.
- Never expose stack traces or internal details in production error responses.
- The middleware is the **single place** where exceptions are mapped to HTTP responses.
- API endpoints do **not** catch domain exceptions — they let them propagate to the middleware.


---
