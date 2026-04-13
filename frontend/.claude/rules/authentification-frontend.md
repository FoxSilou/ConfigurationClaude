# Règle : Authentification frontend

## Principe

L'authentification est une **préoccupation d'infrastructure** : elle est gérée par des adapters (intercepteurs HTTP, `AuthenticationStateProvider`) et n'apparaît **jamais** dans les Presenters ni dans les pages métier sous forme de logique custom.

## Stockage du token

- Le token (JWT ou équivalent) est stocké via un port `ITokenStorage` dont l'implémentation est un adapter infrastructure.
- Jamais d'accès direct à `localStorage` / `sessionStorage` depuis un Presenter, une page, ou un Gateway métier.

## Propagation du token aux appels API

- Un **DelegatingHandler** (ou intercepteur équivalent) injecte automatiquement le header `Authorization: Bearer <token>` sur le `HttpClient` utilisé par le client NSwag.
- Les Gateways n'ajoutent pas le header manuellement.
- Une réponse `401 Unauthorized` déclenche le flow de déconnexion / redirection côté infra, pas dans le Presenter.

## Contrôle d'accès dans l'UI

- Utiliser `AuthorizeView` / `[Authorize]` pour masquer ou protéger les composants et pages sensibles.
- Les Presenters ne lisent pas `ClaimsPrincipal` directement : s'ils ont besoin de l'utilisateur courant, ils passent par un port `ICurrentUserAccessor` (adapter côté infra qui lit l'`AuthenticationState`).

## Ce qui est interdit

- Lire / écrire le token depuis un Presenter ou une page.
- Hardcoder `Authorization` dans un Gateway.
- Dupliquer la logique de refresh / redirection 401 dans plusieurs Gateways.
- Tester un `ClaimsPrincipal` directement dans un composant métier (utiliser `AuthorizeView` ou le port).
