---
description: "ASP.NET Core Identity as infrastructure adapter — hybrid pattern: domain is source of truth, Identity synchronized via projections"
alwaysApply: false
globs: ["**/Identity/**/*.cs", "**/Infrastructure/**/*User*.cs", "**/Infrastructure/**/*Password*.cs", "**/Infrastructure/**/*Token*.cs", "**/Infrastructure/**/*Auth*.cs"]
---

# Rule: ASP.NET Core Identity — Hybrid Pattern

> **This rule is an optional recipe.** It applies when the project includes a user management / authentication bounded context. If your project does not need user management, this rule can be ignored.

## Core Principle

The domain `Utilisateur` aggregate (event-sourced) is the **single source of truth**. ASP.NET Core Identity is an **infrastructure detail** synchronized via domain event projections. `UserManager<ApplicationUser>` is used **read-only** in infrastructure — never for writes. All mutations go through the domain.

## Architecture

```
Domain (source of truth)              Infrastructure (projection target)
┌──────────────────────────┐          ┌──────────────────────────────┐
│ Utilisateur              │  events  │ ApplicationUser              │
│  (aggregate, ES)         │ ──────→  │  : IdentityUser<Guid>        │
│  - RoleUtilisateur       │ project  │  - Pseudonyme, Statut        │
│  - MotDePasseHash        │          │  - PasswordHash (Identity)   │
│  - domain events         │          │  - AspNetUserRoles           │
└──────────────────────────┘          └──────────────────────────────┘
         ↑ write                             ↑ read-only
    Commands / Handlers               UserManager (login, role query)
```

## Key Design Decisions

- **`AppIdentityDbContext`** shares the Read database — Identity tables (`AspNet*`) cohabit with read models
- **`ApplicationUser`** is infrastructure-only — no `ToDomain()`/`FromDomain()` since event sourcing is the persistence mechanism
- **Projections** (one per domain event) sync domain events → Identity tables via `UserManager`
- **Login** is a Command — reads from Identity tables via `IUtilisateurAuthReader`, returns a JWT value object

## Password Handling

### Flow

1. **Validation** — `MotDePasse.Creer(raw)` validates business rules. Transient — never stored.
2. **Hashing** — `IPasswordHasher.Hash(raw)` → `MotDePasseHash`. Implementation uses Identity's `PasswordHasher<T>`.
3. **Storage** — Hash stored in event store (aggregate) AND projected to `ApplicationUser.PasswordHash`.
4. **Verification** — `IPasswordHasher.Verifier(raw, hash)` delegates to Identity's `PasswordHasher<T>`.

### Rules

- **Never store raw passwords** in the domain. `Utilisateur` holds `MotDePasseHash`, not `MotDePasse`.
- **`MotDePasse`** is a validation-only value object. Discarded after the handler uses it.
- **`MotDePasseHash`** is an opaque storage value object. `Reconstituer(string)` for persistence.
- The **`IPasswordHasher`** port returns `MotDePasseHash`, not a raw string.

## Roles

- **`RoleUtilisateur`** is a domain value object (enum-encapsulated: `Utilisateur`, `Administrateur`)
- Roles are assigned via `Utilisateur.AttribuerRole()` → raises `RoleAttribue` event
- `RoleAttribueIdentityProjection` syncs to `AspNetUserRoles` via `UserManager`
- Default role on inscription: `RoleUtilisateur.Utilisateur`

## Authentication (JWT)

### Ports

| Port | Location | Purpose |
|---|---|---|
| `IPasswordHasher` | `Application/Ports` | Hash + verify passwords |
| `ITokenGenerator` | `Application/Ports` | Generate JWT from user info + roles |
| `IUtilisateurAuthReader` | `Application/Ports` | Read auth data (email → id, hash, pseudonyme, roles) |
| `ILoginAttemptTracker` | `Application/Ports` | Lockout check, record failed attempts, reset on success |

### Flow

1. `SeConnecter` command → handler checks lockout via `ILoginAttemptTracker`
2. Reads auth info via `IUtilisateurAuthReader`
3. Verifies password via `IPasswordHasher` (records failure via `ILoginAttemptTracker` if wrong)
4. Resets attempt counter via `ILoginAttemptTracker` on success
5. Generates JWT via `ITokenGenerator` with claims: `sub`, `email`, `name`, `role`
6. Returns `JetonAuthentification` value object

### Infrastructure Implementations

| Port | Implementation | Source |
|---|---|---|
| `IPasswordHasher` | `IdentityPasswordHasher` | Identity's `PasswordHasher<ApplicationUser>` |
| `ITokenGenerator` | `JwtTokenGenerator` | `IConfiguration` (Jwt section) |
| `IUtilisateurAuthReader` | `EfCoreUtilisateurAuthReader` | `UserManager<ApplicationUser>` |
| `ILoginAttemptTracker` | `IdentityLoginAttemptTracker` | `UserManager` (lockout + access failed) |

## Accès à l'utilisateur courant

### Principe

L'extraction de l'identifiant et des rôles depuis le `ClaimsPrincipal` est **interdite dans les endpoints API et les handlers**. Elle passe **toujours** par le port `ICurrentUserAccessor` qui retourne le Value Object `UtilisateurCourant`. Aucun endpoint ni handler ne doit manipuler `ClaimsPrincipal`, `FindFirst`, `FindAll`, ou des claim type strings.

### Port (Application)

```csharp
public interface ICurrentUserAccessor
{
    UtilisateurCourant? Obtenir();  // null si non authentifié
}
```

### Value Object (Domain)

```csharp
public readonly record struct UtilisateurCourant
{
    public UtilisateurId Id { get; }
    public IReadOnlyCollection<RoleUtilisateur> Roles { get; }

    public bool EstAdministrateur => Roles.Any(r => r == RoleUtilisateur.Administrateur);

    public static UtilisateurCourant Creer(UtilisateurId id, IEnumerable<RoleUtilisateur> roles);
}
```

### Adapter (Infrastructure)

`HttpContextCurrentUserAccessor` utilise les APIs natives :

- `IHttpContextAccessor` (enregistré via `services.AddHttpContextAccessor()`)
- **`UserManager<ApplicationUser>.GetUserId(ClaimsPrincipal)`** — API native Identity, à préférer à `FindFirst(ClaimTypes.NameIdentifier)` car elle respecte `IdentityOptions.ClaimsIdentity.UserIdClaimType`
- `user.FindAll(ClaimTypes.Role)` pour les rôles depuis le token (ils y sont écrits par `JwtTokenGenerator`, donc pas de round-trip DB)

### Règles d'utilisation

- **Endpoints** : injecter `ICurrentUserAccessor` directement dans la signature minimal API. L'endpoint ne lit jamais `ClaimsPrincipal`.
- **Handlers de commande** : injecter `ICurrentUserAccessor` plutôt que de recevoir `demandeurId` / `roles` en paramètre de commande.
- **Commandes** : ne portent **jamais** l'identifiant ou les rôles de l'utilisateur courant en paramètres. Une commande modélise l'intention métier (cible, données), pas le contexte d'authentification.
- **Autorisation HTTP** « être authentifié » : `RequireAuthorization()` ou `[Authorize]`.
- **Autorisation métier** (« seul un admin peut X, ou X soi-même ») : dans le handler, en utilisant `currentUser.Obtenir()` puis lecture de `EstAdministrateur` / `Id`. Lever `DomainException` si refusé → mappée 403 par le middleware Problem Details.
- **Autorisation purement technique par rôle** (sans règle métier) : `[Authorize(Roles = "Administrateur")]` ou `RequireAuthorization(p => p.RequireRole("Administrateur"))`.

### Tests

- Unit tests : utiliser un **Fake** `ICurrentUserAccessor` (ex. `FakeCurrentUserAccessor` qui retourne un `UtilisateurCourant` configurable). Pas de Mock (cf. `unit-testing.md`).
- E2E : aucun changement, l'auth passe par le JWT généré par `SeConnecter` et le header `Authorization: Bearer …`.

## Connection String — partagée avec Read

- `AppIdentityDbContext` utilise la **chaîne `Read` existante** (`builder.Configuration.GetConnectionString("Read")`).
- **❌ Ne PAS ajouter une troisième clé `"Identity"` dans `appsettings*.json`.** Deux chaînes seulement : `Write` et `Read`.
- **❌ Ne PAS créer de base séparée `<Solution>_Identity`.** Les tables `AspNet*` cohabitent avec les read models dans `<Solution>_Read`.
- Le câblage DI passe la Read connection string directement : `AddWriteIdentite(config, readConnectionString)` — pas de paramètre `identityConnectionString`.

Raison : les projections (`UtilisateurInscritIdentityProjection`, etc.) écrivent à la fois dans les tables Identity et dans les read models. Une seule base = une seule transaction logique, une seule seed, une seule chaîne à gérer.

## Persistence Model

```csharp
// Infrastructure — no ToDomain/FromDomain (event sourcing is the source of truth)
internal sealed class ApplicationUser : IdentityUser<Guid>
{
    public string Pseudonyme { get; set; } = string.Empty;
    public string Statut { get; set; } = string.Empty;
}
```

## DbContext

`AppIdentityDbContext : IdentityDbContext<ApplicationUser, IdentityRole<Guid>, Guid>` — points to Read DB connection string.

## Projections (Domain Events → Identity / Email)

| Event | Projection | Action |
|---|---|---|
| `UtilisateurInscrit` | `UtilisateurInscritIdentityProjection` | `UserManager.CreateAsync()` + `AddToRoleAsync()` |
| `UtilisateurInscrit` | `UtilisateurInscritEmailProjection` | `IEmailSender.EnvoyerEmailDeConfirmationAsync()` |
| `RoleAttribue` | `RoleAttribueIdentityProjection` | `UserManager.RemoveFromRolesAsync()` + `AddToRoleAsync()` |

## Email de confirmation

L'email de confirmation est envoyé via une **projection** sur `UtilisateurInscrit` (side-effect découplé du command handler).

- **Port** : `IEmailSender` dans `Application/Ports/` — prend `AdresseEmail` et `TokenDeConfirmation` (Value Objects)
- **Projection** : `UtilisateurInscritEmailProjection` dans `Infrastructure/Projections/` — `IDomainEventHandler<UtilisateurInscrit>`
- **Adaptateurs** : sélection via configuration (`Email:Provider` dans `appsettings.json`)
  - `LogEmailSender` — log le token dans la console (dev, `"Provider": "Log"`)
  - `SmtpEmailSender` — envoi réel via MailKit (prod, `"Provider": "Smtp"`)
- Le `TokenDeConfirmation` est généré dans l'agrégat à l'inscription et porté par l'événement `UtilisateurInscrit`

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Identity user model | `ApplicationUser` | `internal sealed class ApplicationUser : IdentityUser<Guid>` |
| Identity DbContext | `AppIdentityDbContext` | Shares Read DB connection |
| Port → Impl | `I<Role>` → `<Technology><Role>` | `ITokenGenerator` → `JwtTokenGenerator` |
| Identity projections | Event name + `IdentityProjection` | `<Event>IdentityProjection` |
| Login command | French verb | Domain ubiquitous language |
| JWT value object | `readonly record struct` | Wraps token string |
| Role value object | Enum-encapsulated | Static instances + `Creer(string)` validation |

## Sécurité basique

### Politique de mot de passe

- Les invariants de mot de passe sont définis dans le Value Object `MotDePasse` (domaine) : longueur minimale 8 caractères, au moins 1 majuscule, 1 chiffre, 1 caractère spécial.
- Les options `Identity` dans `AddIdentity<>()` doivent être synchronisées avec ces invariants domaine (double barrière défensive).
- `MotDePasse` est un VO transient (validation uniquement) — jamais stocké. Le hash est dans `MotDePasseHash`.

### Anti brute-force (lockout)

- **Configuration Identity** : activer `Lockout` dans `AddIdentity<>()` options :
  ```csharp
  options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
  options.Lockout.MaxFailedAccessAttempts = 5;
  options.Lockout.AllowedForNewUsers = true;
  ```
- **Port `ILoginAttemptTracker`** (Application/Ports) : vérifie et enregistre les tentatives de connexion. Trois méthodes :
  - `EstVerrouilleAsync(string email, ct)` → `bool`
  - `EnregistrerEchecAsync(string email, ct)` — incrémente le compteur d'échecs
  - `ReinitialiserAsync(string email, ct)` — remet à zéro après un succès
- **Implémentation `IdentityLoginAttemptTracker`** (Infrastructure) : délègue à `UserManager.IsLockedOutAsync()`, `AccessFailedAsync()`, `ResetAccessFailedCountAsync()`.
- **Le handler `SeConnecter`** doit :
  1. Vérifier le lockout **avant** la vérification du mot de passe
  2. Enregistrer un échec si le mot de passe est incorrect
  3. Réinitialiser le compteur après un succès

### Rate limiting

- Utiliser `AddRateLimiter()` (ASP.NET Core) avec une politique `"auth"` (fixed window : 5 requêtes/minute).
- Appliquer `.RequireRateLimiting("auth")` sur les endpoints `/api/identite/connexion` et `POST /api/identite/utilisateurs`.
- Le rejet retourne `429 Too Many Requests`.

### Messages d'erreur génériques

- Le message d'erreur de login est toujours `"Email ou mot de passe incorrect."` — que l'email n'existe pas OU que le mot de passe soit faux. Ne jamais révéler lequel.
- Le message de lockout est `"Compte temporairement verrouillé. Réessayez plus tard."` — ne jamais indiquer le nombre de tentatives restantes.

### CORS

- En développement : `AllowAnyOrigin()` acceptable.
- En production : restreindre aux domaines frontend autorisés.

### Seed administrateur (event-sourced)

- **Principe** : pas d'insertion directe dans l'event store ni les read models. On rejoue les commandes existantes via `ICommandBus` au démarrage — les events produits alimentent l'event store, puis les projections l'Identity DB et les read models naturellement.
- **Séquence** (cas où l'utilisateur n'existe pas) :
  1. `ICommandBus.EnvoyerAsync<InscrireUtilisateur, UtilisateurId>(new InscrireUtilisateur(email, pseudonyme, motDePasse))` → retourne l'`UtilisateurId`
  2. Recharger l'agrégat via `IUtilisateurRepository.ObtenirParIdAsync(id)` pour lire `TokenDeConfirmation.Valeur` (le handler d'inscription ne le retourne pas)
  3. `ICommandBus.EnvoyerAsync(new ConfirmerEmail(id.Valeur, token))` → passe le statut à `EmailConfirme`
  4. `ICommandBus.EnvoyerAsync(new AttribuerRole(id.Valeur, RoleUtilisateur.Administrateur.Valeur))`
- **Configuration** : section `IdentitySeed` dans `appsettings.json` avec `Email` et `Pseudonyme`. Le mot de passe n'est **jamais** commité — user-secrets (`dotnet user-secrets init --project src/Api` puis `dotnet user-secrets set "IdentitySeed:Password" "<mdp>" --project src/Api`) ou variable d'environnement `IdentitySeed__Password`.
- **Idempotence** : guard obligatoire via `IUtilisateurRepository.ExisteParEmailAsync(email)` avant tout dispatch. Tolérer `DomainException` "existe déjà" dans un `try/catch` comme filet de sécurité (race au premier boot).
- **Si section/password manquant** : log warning et skip — pas d'exception, pas de crash au démarrage.
- **Intégration** : classe statique `AdministrateurSeeder.EnsureAdministrateurAsync(IServiceProvider serviceProvider, CancellationToken ct = default)` dans `Identity.Write.Infrastructure/Persistence/`. Appelée dans `Program.cs` dans le même `using var scope = app.Services.CreateScope()` que `IdentityDataSeeder.EnsureIdentityDatabaseAsync`, **juste après** celui-ci (les tables Identity doivent exister et les rôles être seedés avant).
- **Logs** : `LogInformation` quand seed exécuté ("Seed administrateur en cours pour {Email}…" / "Seed administrateur réussi pour {Email} (id {Id})."), `LogInformation` si déjà présent, `LogWarning` si config incomplète.
- **Ordonnancement scaffold ↔ feature — finalisation incrémentale** : le seeder dépend des commandes `InscrireUtilisateur`, `ConfirmerEmail` et `AttribuerRole`, produites par `/task-implement-feature-back` (et non par le scaffold). Il est construit **par addition**, un step par commande, pas en bloc final. L'agent `implement-feature` détecte la commande qu'il vient d'implémenter et met à jour le seeder en conséquence.

  | Étape | Déclenché par | Effet sur `AdministrateurSeeder.cs` | Effet sur `Program.cs` |
  |---|---|---|---|
  | Scaffold BC | `/task-scaffold-back Identite` | Stub : roadmap en commentaire + `throw new NotImplementedException("Finaliser après implémentation de InscrireUtilisateur/ConfirmerEmail/AttribuerRole.")` | Appel **commenté** avec note « activé une fois les 3 commandes implémentées », placé juste après `IdentityDataSeeder.EnsureIdentityDatabaseAsync` dans le même scope DI |
  | Feature 1/3 | `/task-implement-feature-back InscrireUtilisateur` | Charger config (`Email`, `Pseudonyme`, `Password`), warning+return si incomplet, guard `ExisteParEmailAsync`, dispatch `InscrireUtilisateur` et capturer `UtilisateurId`. Conserver `throw new NotImplementedException("Suite : ConfirmerEmail + AttribuerRole.")` en fin de méthode | Inchangé (toujours commenté) |
  | Feature 2/3 | `/task-implement-feature-back ConfirmerEmail` | Après le dispatch `InscrireUtilisateur` : reload via `IUtilisateurRepository.ObtenirParIdAsync(id)` pour lire `TokenDeConfirmation.Valeur`, puis dispatch `ConfirmerEmail`. Actualiser le message du `throw` terminal en `"Suite : AttribuerRole."` | Inchangé (toujours commenté) |
  | Feature 3/3 | `/task-implement-feature-back AttribuerRole` | Ajouter `ICommandBus.EnvoyerAsync(new AttribuerRole(id.Valeur, RoleUtilisateur.Administrateur.Valeur))`. **Supprimer** le `throw NotImplementedException` terminal. Ajouter `LogInformation` succès. | **Décommenter** `await AdministrateurSeeder.EnsureAdministrateurAsync(scope.ServiceProvider);` |

  **Règle d'ordre des 3 stories** : libre. L'agent implémente celle que l'utilisateur demande et détecte l'état courant du seeder (présence/absence des dispatchs `InscrireUtilisateur`, `ConfirmerEmail`, `AttribuerRole`) pour insérer son step au bon endroit. Le `throw` terminal est remplacé / mis à jour à chaque passage.

  **Garde-fou** : tant que les 3 dispatchs ne sont pas là, l'appel reste commenté dans `Program.cs`. Le `throw NotImplementedException` terminal du seeder n'est donc jamais exécuté en pratique — il sert de filet si quelqu'un décommente prématurément.

  **Ne pas exécuter l'API** tant que les 3 commandes ne sont pas implémentées via un appel décommenté : crash au boot garanti sur le `throw`.

## SeConnecter (connexion)

La commande `SeConnecter` est **stubbée au scaffold** (Mode 2, Identity Setup) et **implémentée via `/task-implement-feature-back`**. Elle n'intervient pas dans le seeder administrateur (orthogonal — le seeder crée un admin, la connexion permet à n'importe quel utilisateur de s'authentifier).

### Ordonnancement scaffold ↔ feature

| Étape | Déclenché par | Produit |
|---|---|---|
| Scaffold BC | `/task-scaffold-back Identite` | Stub `SeConnecter(string Email, string MotDePasse) : ICommand<JetonAuthentification>` avec handler `throw new NotImplementedException(...)`. Endpoint `POST /api/identite/connexion` câblé avec `.RequireRateLimiting("auth")` + annotations OpenAPI. Request/Response models dans l'API layer. |
| Feature | `/task-implement-feature-back SeConnecter` | Handler body : vérification lockout (`ILoginAttemptTracker.EstVerrouilleAsync`), lecture auth data (`IUtilisateurAuthReader`), vérification password (`IPasswordHasher.Verifier`), tracking tentatives (échec/reset), génération JWT (`ITokenGenerator`). Tests unitaires + E2E. |

### Stub command (scaffold)

```csharp
// Identite.Write.Application/SeConnecter.cs
public sealed record SeConnecter(string Email, string MotDePasse) : ICommand<JetonAuthentification>
{
    public sealed class Handler(
        IUtilisateurAuthReader authReader,
        IPasswordHasher passwordHasher,
        ITokenGenerator tokenGenerator,
        ILoginAttemptTracker loginAttemptTracker,
        TimeProvider timeProvider) : ICommandHandler<SeConnecter, JetonAuthentification>
    {
        public Task<JetonAuthentification> HandleAsync(SeConnecter commande, CancellationToken ct = default)
        {
            throw new NotImplementedException(
                "Implémenter via /task-implement-feature-back SeConnecter.");
        }
    }
}
```

### Endpoint (scaffold)

```csharp
app.MapPost("/api/identite/connexion", async (ConnexionRequest request, ICommandBus commandBus, CancellationToken ct) =>
{
    var commande = new SeConnecter(request.Email, request.MotDePasse);
    var jeton = await commandBus.EnvoyerAsync<SeConnecter, JetonAuthentification>(commande, ct);
    return Results.Ok(new ConnexionResponse(jeton.Valeur, jeton.Expiration));
})
    .WithName("SeConnecter")
    .WithTags("Identite")
    .Produces<ConnexionResponse>()
    .ProducesProblem(StatusCodes.Status400BadRequest)
    .ProducesProblem(StatusCodes.Status429TooManyRequests)
    .RequireRateLimiting("auth");
```

Request/Response models (dans l'API layer, pas dans Application) :

```csharp
internal sealed record ConnexionRequest(string Email, string MotDePasse);
internal sealed record ConnexionResponse(string Token, DateTimeOffset Expiration);
```

### Garde-fou

Tant que le handler n'est pas implémenté, tout appel à `POST /api/identite/connexion` retourne une `500 Internal Server Error` (le `NotImplementedException` est attrapé par le middleware Problem Details). C'est acceptable : le scaffold pose le plumbing, la logique métier arrive avec la feature.

## SeDeconnecter (déconnexion)

La déconnexion **ne nécessite pas de commande backend**. Le JWT est stateless ; la déconnexion consiste à :

1. Supprimer le token côté client via `ITokenStorage.SupprimerAsync()`
2. Notifier le changement d'état auth via `AuthenticationStateProvider.NotifyAuthenticationStateChanged()`
3. Rediriger vers `/connexion` (optionnel, selon l'UX)

Le scaffold frontend produit une méthode `SeDeconnecterAsync()` dans le `ConnexionPresenter` qui enchaîne ces opérations. Voir rule `authentification-frontend.md` § Déconnexion.

**Remarque** : un compte supprimé (`StatutUtilisateur.Supprime`) a `LockoutEnd = DateTimeOffset.MaxValue` dans Identity — même si un ancien JWT non-expiré circule encore, le prochain appel à `SeConnecter` échouera via `ILoginAttemptTracker.EstVerrouilleAsync`. La déconnexion client-side est donc suffisante pour couper l'accès immédiat, et le lockout serveur empêche la reconnexion.

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---|---|---|
| Using `UserManager` to create/update users directly | Bypasses domain — Identity is a projection target, not a write model | All writes go through the aggregate → domain events → projection |
| Adding `ToDomain()`/`FromDomain()` on `ApplicationUser` | Event sourcing is the persistence mechanism, not Identity tables | `ApplicationUser` is infrastructure-only, synced via projections |
| Putting `PasswordHasher<T>` or `UserManager` in Application layer | Identity is infrastructure — Application only knows ports | Use `IPasswordHasher`, `IUtilisateurAuthReader` ports |
| Returning Identity types (`IdentityResult`, `ApplicationUser`) from ports | Leaks infrastructure into Application | Ports return domain Value Objects or primitives |
| Using `MigrateAsync()` in startup without guarding | Breaks build-time OpenAPI generation (no DB available) | Use SQL table-existence check + `CreateTablesAsync()` |
| Not checking lockout in login handler | Brute-force attacks succeed without limit | Check `ILoginAttemptTracker.EstVerrouilleAsync()` before password verification |
| Omitting rate limiting on auth endpoints | Automated attacks can flood login/registration | Apply `RequireRateLimiting("auth")` on sensitive endpoints |
| Permissive password policy in production | Weak passwords compromise accounts | Enforce invariants in `MotDePasse` VO + synchronize Identity options |
| Ajouter une 3ᵉ connection string `"Identity"` + base `_Identity` distincte | Viole la règle « shares the Read database » ; projections écrivent dans 2 bases séparées, migrations/seed dédoublés, pas d'atomicité projections ↔ read models | Réutiliser `GetConnectionString("Read")` ; jamais de clé `"Identity"` dans `ConnectionStrings` |
| Seeding admin via `INSERT` SQL or `UserManager.CreateAsync` at startup | Bypasses event store — no events produced, projections drift | Dispatch `InscrireUtilisateur` + `ConfirmerEmail` + `AttribuerRole` through `ICommandBus` (see § Seed administrateur) |
| Hardcoding admin password in `appsettings.json` | Secret leaks via git history | Config holds email/pseudo only; password via `dotnet user-secrets` or env var `IdentitySeed__Password` |
| Extraire `sub`/`roles` manuellement depuis `ClaimsPrincipal` dans un endpoint ou un handler | Duplication, fuite de claims dans la couche HTTP, fragile (claim mapping JWT, fallback `?? "sub"` inutile) | Injecter `ICurrentUserAccessor` et appeler `Obtenir()` |
| Passer `roles` ou `demandeurId` en paramètre de commande depuis l'endpoint | Couple le domaine au transport HTTP, contourne le port, pollue la signature de la commande | Le handler injecte `ICurrentUserAccessor` et lit le contexte lui-même |
| Utiliser `FindFirstValue(ClaimTypes.NameIdentifier)` au lieu de `UserManager.GetUserId(user)` | Ne respecte pas `IdentityOptions.ClaimsIdentity.UserIdClaimType` configuré dans Identity | `UserManager<ApplicationUser>.GetUserId(ClaimsPrincipal)` est l'API officielle Identity, exclusivement dans l'adaptateur `HttpContextCurrentUserAccessor` |
| Ne pas scaffolder `SeConnecter` dans le BC Identite | L'app a toute l'infra auth (JWT, ports, adapters, rate limiting) mais aucun moyen pour l'utilisateur de se connecter — le flux d'inscription est complet mais inutilisable | `SeConnecter` fait partie du scaffold Identity Setup (Mode 2 Phase 1), pas d'une feature optionnelle — voir § SeConnecter ci-dessus |


---
