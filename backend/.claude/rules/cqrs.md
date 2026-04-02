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
│   ├── <BC>.Write.Domain.csproj
│   │   ├── Aggregates/
│   │   ├── Entities/
│   │   ├── ValueObjects/
│   │   ├── Events/
│   │   └── Ports/                  # Write repositories
│   ├── <BC>.Write.Application.csproj
│   │   ├── <CommandFiles>.cs       # Commands + handlers (flat, no Commands/ subfolder)
│   │   ├── Behaviors/              # Pipeline behaviors
│   │   └── Ports/                  # Write service interfaces
│   └── <BC>.Write.Infrastructure.csproj  # Write adapters (EventStore, EF Core, etc.)
└── Read/
    ├── <BC>.Read.Application.csproj
    │   ├── <QueryFiles>.cs         # Queries + handlers (flat, no Queries/ subfolder)
    │   └── Ports/                  # Read-specific service interfaces
    └── <BC>.Read.Infrastructure.csproj  # Read adapters (ReadDbContext, Dapper, projections)
```

**Important**: projects (`.csproj`) are placed **directly** under `Write/` or `Read/` — no `Domain/`, `Application/`, or `Infrastructure/` subdirectories.

## Rules

- **Read and Write never reference each other.** They are independent stacks.
- **Shared abstractions** (`AggregateRoot<TId>`, `ICommand<T>`, `IQuery<T>`, `IDomainEvent`, `ICommandBus`, `IQueryBus`, etc.) live in `Shared.Write.Domain`.
- **The Write side** owns the rich Domain (aggregates, entities, value objects, events) and the Commands.
- **The Read side** is optimized for reading: it can use lightweight read models, Dapper, projections, or a dedicated read DbContext. It does not need to go through Write-side aggregates.
- **Queries never modify state** — no writes, no events.
- **Commands never return complex data** — only the created Id or `Unit`.
- **Commands and Queries are flat** — placed directly in `Application/`, not in `Commands/` or `Queries/` subfolders.

## Physical separation by default

Each layer (Domain, Application, Infrastructure) is always its own `.csproj` project from the start. This ensures strict dependency control and prevents accidental coupling.


---
