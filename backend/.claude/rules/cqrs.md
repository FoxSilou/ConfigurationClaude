---
description: "CQRS — strict Read/Write separation across all layers"
alwaysApply: true
---

# Rule: CQRS — Read / Write Separation

## Core Principle

The project follows **strict CQRS**: the Read (Query) and Write (Command) sides are **fully separated** across all layers. Each Bounded Context has its own Read and Write stack.

## Structure

```
src/<BoundedContext>/
├── Write/
│   ├── Domain/
│   │   ├── Aggregates/
│   │   ├── Entities/
│   │   ├── ValueObjects/
│   │   ├── Events/
│   │   └── Ports/              # Write repositories
│   ├── Application/
│   │   ├── <CommandFiles>.cs   # Commands + handlers (flat, no Commands/ subfolder)
│   │   ├── Behaviors/          # Pipeline behaviors
│   │   └── Ports/              # Write service interfaces
│   ├── Infrastructure/         # Write adapters
│   └── Api/                    # Write endpoints
└── Read/
    ├── Application/
    │   ├── <QueryFiles>.cs     # Queries + handlers (flat, no Queries/ subfolder)
    │   └── Ports/              # Read-specific service interfaces
    ├── Infrastructure/         # Read adapters (read DbContext, Dapper, etc.)
    └── Api/                    # Read endpoints
```

## Rules

- **Read and Write never reference each other.** They are independent stacks.
- **Shared abstractions** (`AggregateRoot<TId>`, `ICommand<T>`, `IQuery<T>`, `IDomainEvent`, `ICommandBus`, `IQueryBus`, etc.) live in `SharedKernel`.
- **The Write side** owns the rich Domain (aggregates, entities, value objects, events) and the Commands.
- **The Read side** is optimized for reading: it can use lightweight read models, Dapper, projections, or a dedicated read DbContext. It does not need to go through Write-side aggregates.
- **Queries never modify state** — no writes, no events.
- **Commands never return complex data** — only the created Id or `Unit`.
- **Commands and Queries are flat** — placed directly in `Application/`, not in `Commands/` or `Queries/` subfolders.

## When to separate physically vs logically

- **Logical separation (folders)**: for small Bounded Contexts, Read and Write are folders within the same project.
- **Physical separation (projects)**: when the BC grows, Read and Write become separate .NET projects.

Start with folders, migrate to projects when needed.


---
