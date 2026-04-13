# Règle : Routing & contrat d'API — backend maître

## Principe

Le **backend est maître** sur les URLs des endpoints HTTP. Le frontend ne définit, ne devine, ni ne hardcode jamais une URL d'endpoint. Il consomme un **contrat généré** à partir de la spec OpenAPI du backend (`backend/Api.json`) via **NSwag**.

## Flux du contrat

```
backend (ASP.NET Core)
   └── build → génère Api.json (OpenAPI spec)
         └── NSwag (MSBuild target dans UI.Infrastructure)
               └── génère client typé : IImperiumRexApiClient + DTOs
                     └── utilisé par les Gateways frontend
```

La régénération est automatique au build du frontend si `Api.json` existe. Un rebuild du backend met à jour `Api.json`, puis le rebuild frontend met à jour le client.

## Ce qui est interdit

- **Hardcoder une URL** d'endpoint backend dans un Gateway, un service, ou une page (ex. `"/api/utilisateurs"`, `$"/api/utilisateurs/{id}"`).
- Injecter un `HttpClient` brut dans un Gateway pour faire un `GetAsync("/api/...")` manuel.
- Définir côté frontend les **DTOs** ou **operationId** correspondant à des endpoints backend (ils viennent du client généré).
- Modifier le code généré par NSwag à la main.

## Ce qui est attendu

- Les Gateways (`UI.Infrastructure/Gateways/`) injectent `IImperiumRexApiClient` (ou nom équivalent du client NSwag) via constructeur.
- Les appels passent par les méthodes typées générées (ex. `client.InscrireUtilisateurAsync(...)`).
- Les DTOs proviennent du namespace généré (`ApiClient/`), ou sont mappés vers les types du `UI.Domain` dans le Gateway.
- Le Gateway attrape `ApiException` et la transforme en `Result<T>` ou état d'erreur pour le Presenter.

## Si un endpoint manque côté frontend

Diagnostic avant de coder :

1. L'endpoint existe-t-il dans le backend ? → si non, implémenter backend d'abord.
2. `backend/Api.json` est-il à jour ? → rebuild backend pour le régénérer.
3. Le client NSwag est-il régénéré ? → rebuild frontend (`UI.Infrastructure`).

**Jamais** contourner en écrivant un appel HTTP manuel "en attendant".

## Routing Blazor (client-side)

La règle ci-dessus concerne les endpoints **backend**. Le routing **Blazor** (pages `.razor` avec `@page "/..."`) est défini côté frontend et reste sous contrôle frontend — il n'a aucun lien avec les URLs d'API.
