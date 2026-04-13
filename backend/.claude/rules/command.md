---
description: "Command pattern — sealed record + nested Handler, ICommand<T> (no MediatR in Application)"
globs: ["**/Application/**/*.cs", "**/Write/**/*.cs"]
---

# Rule: Command Pattern

## Structure

A command and its handler are always in the **same file**, with the handler as a **nested class** inside the command.

**⚠️ RÈGLE CRITIQUE**: `ICommand<T>` et `ICommandHandler<TCommand, TResult>` sont des **interfaces génériques définies dans Shared.Write.Domain**. Elles ne référencent **JAMAIS** MediatR. MediatR est un détail d'infrastructure — l'adaptateur MediatR dans Infrastructure fait le pont entre ces interfaces et `IRequest`/`IRequestHandler` de MediatR. Ni le Command, ni le Handler ne doivent avoir de `using MediatR`.

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
- Commands live directly in `the Write Application project` (flat, no `Commands/` subfolder).
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

## Nommage des paramètres de commande — collisions avec les Value Objects

Les paramètres de la `record` command portent un **nom primitif reflétant le sens métier** : `Email`, `Pseudonyme`, `MotDePasse`, `Nom`. Ils ne prennent **pas** de suffixe artificiel (`EmailBrut`, `PseudonymeString`) pour éviter la collision avec les Value Objects de même nom.

**Conséquence** : dans le handler, l'appel à la factory du VO doit utiliser le **nom pleinement qualifié** quand le paramètre de la commande cache le type :

```csharp
public sealed record InscrireUtilisateur(string Email, string Pseudonyme, string MotDePasse)
    : ICommand<UtilisateurId>
{
    public sealed class Handler(IUtilisateurRepository repo, IPasswordHasher hasher, TimeProvider time)
        : ICommandHandler<InscrireUtilisateur, UtilisateurId>
    {
        public async Task<UtilisateurId> HandleAsync(InscrireUtilisateur commande, CancellationToken ct = default)
        {
            var email = AdresseEmail.Creer(commande.Email);
            // ⚠️ fully-qualified — commande.Pseudonyme cache le type Pseudonyme
            var pseudonyme = Identite.Write.Domain.ValueObjects.Pseudonyme.Creer(commande.Pseudonyme);
            var motDePasse = Identite.Write.Domain.ValueObjects.MotDePasse.Creer(commande.MotDePasse);
            // ...
        }
    }
}
```

**Interdit** :
- Renommer le paramètre de la commande pour éviter la collision (`PseudonymeBrut`, `PseudonymeString`) — cela dégrade le vocabulaire ubiquitaire exposé par le contrat commande.
- Utiliser des `using` alias pour raccourcir — la qualification complète est explicite et locale au handler.


---
