---
description: "MediatR Pipeline Behaviors — validation, logging, transaction (Infrastructure only)"
alwaysApply: false
globs: ["**/Infrastructure/**/*.cs", "**/Behaviors/**/*.cs"]
---

# Rule: Pipeline Behaviors

## Core Principle

Pipeline behaviors are **cross-cutting concerns** that wrap command/query handling. They are implemented using MediatR's `IPipelineBehavior<,>` and live **exclusively in Infrastructure** (since MediatR is an infrastructure detail).

## Standard Behaviors

### ValidationBehavior

Runs FluentValidation validators (if registered) before the handler executes. Applies to commands only.

```csharp
// Infrastructure/Behaviors/ValidationBehavior.cs
internal sealed class ValidationBehavior<TRequest, TResponse>(
    IEnumerable<IValidator<TRequest>> validators)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken ct)
    {
        if (!validators.Any()) return await next();

        var context = new ValidationContext<TRequest>(request);
        var failures = validators
            .Select(v => v.Validate(context))
            .SelectMany(r => r.Errors)
            .Where(f => f is not null)
            .ToList();

        if (failures.Count > 0)
            throw new ValidationException(failures);

        return await next();
    }
}
```

### LoggingBehavior

Logs command/query execution with timing. Useful for observability.

```csharp
// Infrastructure/Behaviors/LoggingBehavior.cs
internal sealed class LoggingBehavior<TRequest, TResponse>(
    ILogger<LoggingBehavior<TRequest, TResponse>> logger)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken ct)
    {
        var requestName = typeof(TRequest).Name;
        logger.LogInformation("Handling {RequestName}", requestName);

        var sw = Stopwatch.StartNew();
        var response = await next();
        sw.Stop();

        logger.LogInformation("Handled {RequestName} in {ElapsedMs}ms", requestName, sw.ElapsedMilliseconds);
        return response;
    }
}
```

### TransactionBehavior (commands only)

Wraps command handling in a database transaction. Dispatches domain events after commit.

```csharp
// Infrastructure/Behaviors/TransactionBehavior.cs
internal sealed class TransactionBehavior<TRequest, TResponse>(
    AppDbContext dbContext)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : ICommand<TResponse>
{
    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken ct)
    {
        await using var transaction = await dbContext.Database.BeginTransactionAsync(ct);
        var response = await next();
        await dbContext.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        return response;
    }
}
```

## Rules

- All behaviors live in `Infrastructure/Behaviors/` — never in Application or Domain.
- Behaviors reference MediatR types (`IPipelineBehavior<,>`) — this is acceptable since they are Infrastructure.
- **Registration** is done in the `AddMessaging()` extension method alongside MediatR setup.
- **Execution order** matters: Logging → Validation → Transaction → Handler.
- The `TransactionBehavior` applies **only to commands** (use type constraints).
- Behaviors must not contain business logic — they are purely technical cross-cutting concerns.

## Registration

```csharp
// In AddMessaging() or DI setup
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(TransactionBehavior<,>));
```


---
