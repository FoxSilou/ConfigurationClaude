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
- **Ordonnancement scaffold ↔ feature** : le seeder dépend des commandes `InscrireUtilisateur`, `ConfirmerEmail` et `AttribuerRole`, qui sont produites par `/task-implement-feature-back` (et non par le scaffold). Règle :
  1. Au scaffold BC Identité (`/task-scaffold-back Identite`), créer le fichier `AdministrateurSeeder.EnsureAdministrateurAsync` avec un corps `throw new NotImplementedException("Finaliser après implémentation de InscrireUtilisateur/ConfirmerEmail/AttribuerRole")`, ajouter la section `IdentitySeed` dans `appsettings.json`, et câbler l'appel dans `Program.cs` dès maintenant (juste après `IdentityDataSeeder.EnsureIdentityDatabaseAsync`, dans le même scope DI).
  2. Ne **pas** exécuter l'API tant que les 3 commandes ne sont pas implémentées (sinon crash au boot).
  3. Après `/task-implement-feature-back` sur les 3 commandes, remplacer le `NotImplementedException` par la séquence complète (guard `ExisteParEmailAsync` + 3 dispatchs `ICommandBus` + logs). Tests E2E doivent passer avec un admin seedé au démarrage.

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
| Seeding admin via `INSERT` SQL or `UserManager.CreateAsync` at startup | Bypasses event store — no events produced, projections drift | Dispatch `InscrireUtilisateur` + `ConfirmerEmail` + `AttribuerRole` through `ICommandBus` (see § Seed administrateur) |
| Hardcoding admin password in `appsettings.json` | Secret leaks via git history | Config holds email/pseudo only; password via `dotnet user-secrets` or env var `IdentitySeed__Password` |
| Extraire `sub`/`roles` manuellement depuis `ClaimsPrincipal` dans un endpoint ou un handler | Duplication, fuite de claims dans la couche HTTP, fragile (claim mapping JWT, fallback `?? "sub"` inutile) | Injecter `ICurrentUserAccessor` et appeler `Obtenir()` |
| Passer `roles` ou `demandeurId` en paramètre de commande depuis l'endpoint | Couple le domaine au transport HTTP, contourne le port, pollue la signature de la commande | Le handler injecte `ICurrentUserAccessor` et lit le contexte lui-même |
| Utiliser `FindFirstValue(ClaimTypes.NameIdentifier)` au lieu de `UserManager.GetUserId(user)` | Ne respecte pas `IdentityOptions.ClaimsIdentity.UserIdClaimType` configuré dans Identity | `UserManager<ApplicationUser>.GetUserId(ClaimsPrincipal)` est l'API officielle Identity, exclusivement dans l'adaptateur `HttpContextCurrentUserAccessor` |


---
