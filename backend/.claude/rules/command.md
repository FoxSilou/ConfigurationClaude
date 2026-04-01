---
description: "Command pattern — sealed record + nested Handler, ICommand<T> (no MediatR in Application)"
globs: ["**/Application/**/*.cs", "**/Write/**/*.cs"]
---

# Rule: Command Pattern

## Structure

A command and its handler are always in the **same file**, with the handler as a **nested class** inside the command.

**⚠️ RÈGLE CRITIQUE**: `ICommand<T>` et `ICommandHandler<TCommand, TResult>` sont des **interfaces génériques définies dans SharedKernel**. Elles ne référencent **JAMAIS** MediatR. MediatR est un détail d'infrastructure — l'adaptateur MediatR dans Infrastructure fait le pont entre ces interfaces et `IRequest`/`IRequestHandler` de MediatR. Ni le Command, ni le Handler ne doivent avoir de `using MediatR`.

```csharp
// ⚠️ NO `using MediatR` here — ICommand/ICommandHandler are OUR interfaces
public sealed record <CommandName>(<Parameters>) : ICommand<<ReturnType>>
{
    public sealed class Handler(<Dependencies>) : ICommandHandler<<CommandName>, <ReturnType>>
    {
        public Task<<ReturnType>> HandleAsync(<CommandName> commande, CancellationToken ct = default)
        {
            // 1. Reconstruct domain objects from primitives (Value Objects, Ids)
            // 2. Delegate to domain (Aggregate factory or method)
            // 3. Persist via port (IRepository)
            // 4. Return typed result
        }
    }
}
```

## Rules

- The command is a `sealed record`.
- The handler is a `sealed class` nested inside the command.
- Dependencies are injected via **primary constructor** on the handler.
- The command name follows the **ubiquitous language** in French (domain language).
- The command parameter is named `commande` in `HandleAsync`.
- The handler never contains domain logic — it orchestrates only.
- Always reconstruct Value Objects and typed Ids from primitives inside the handler before passing them to the domain.
- Commands live directly in `Write/Application/` (flat, no `Commands/` subfolder).
- **⚠️ Aucune référence à MediatR** dans ce fichier. `ICommand<T>` et `ICommandHandler<TCommand, TResult>` sont nos propres interfaces.

## Example

```csharp
public sealed record CreerPartie(string Nom) : ICommand<PartieId>
{
    public sealed class Handler(
        IPartieRepository repository,
        TimeProvider timeProvider) : ICommandHandler<CreerPartie, PartieId>
    {
        public async Task<PartieId> HandleAsync(CreerPartie commande, CancellationToken ct = default)
        {
            var nom = NomDePartie.Creer(commande.Nom);
            var id = PartieId.Nouveau();
            var maintenant = timeProvider.GetUtcNow();
            var partie = Partie.Creer(id, nom, maintenant);

            await repository.AjouterAsync(partie, ct);

            return partie.Id;
        }
    }
}
```

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Command | French infinitive verb + noun, **no** `Command` suffix | `CreerPartie`, `AnnulerCommande` |
| Nested handler | Always `Handler` | `public sealed class Handler(...)` |
| Handler parameter | `commande` | `HandleAsync(CreerPartie commande, ...)` |
| Return type | Typed Id or `Unit` | `PartieId`, `Unit` |
| Domain event | French past participle + noun, **no** suffix | `PartieCree`, `CommandeAnnulee` |


---
