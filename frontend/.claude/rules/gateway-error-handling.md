# Règle : Remontée des erreurs Gateway → Presenter → UI

## Principe

Le backend est la **source unique de vérité du message d'erreur métier**. Il expose ses erreurs via **Problem Details (RFC 7807)** avec un `detail` portant un message français user-ready. Le contrat complet est défini dans `backend/.claude/rules/error-handling.md` :

| Exception backend | Statut HTTP | Nature côté frontend |
|---|---|---|
| `DomainException` | `400` | `ErreurMetierGateway` (extraction `detail`) |
| `NotFoundException` | `404` | `ErreurMetierGateway` (extraction `detail`) |
| `ConcurrencyException` | `409` | `ErreurMetierGateway` (extraction `detail`) |
| Tout le reste (500, réseau, timeout, JSON invalide, 4xx sans `detail`) | — | `ErreurTechniqueGateway` (libellé générique) |

La chaîne de remontée côté frontend doit préserver ce message jusqu'à l'utilisateur :

```
Backend DomainException
   → HTTP 400 Problem Details { detail: "Ce joueur est déjà inscrit." }
   → NSwag ApiException
   → Gateway : ApiExceptionTranslator.Traduire(ex)
   → ErreurMetierGateway("Ce joueur est déjà inscrit.")
   → Presenter : catch → Etat = EnErreur + INotificationService.NotifierErreur(ex.Message)
   → <Notifications /> (Radzen wrapper) affiche une Alert globale user-friendly
```

## Exceptions typées frontend

Définies dans `UI.Domain/Exceptions/`. Deux types et deux seulement.

### `ErreurMetierGateway : Exception`

- Levée quand le backend a renvoyé une exception domaine mappée en Problem Details exploitable : statuts **400** (`DomainException`), **404** (`NotFoundException`), **409** (`ConcurrencyException`).
- Le `Message` porte le `detail` extrait du Problem Details — message français, affichable tel quel à l'utilisateur.

### `ErreurTechniqueGateway : Exception`

- Levée pour tout le reste : 500, erreur réseau, timeout, JSON mal formé, statut 4xx/5xx sans Problem Details exploitable.
- Le `Message` est un libellé générique : `"Une erreur technique est survenue. Réessayez plus tard."`.
- L'exception d'origine est transportée en `InnerException` pour les logs — jamais affichée à l'utilisateur.

## Helper `ApiExceptionTranslator`

Placé dans `UI.Infrastructure/Gateways/ApiExceptionTranslator.cs`. Une seule responsabilité : transformer une `ApiException` NSwag en exception frontend typée.

⚠️ **Piège NSwag** — quand OpenAPI documente un schéma `ProblemDetails` pour un statut (typiquement `400`), NSwag génère une branche qui désérialise le body **en stream** et construit `ApiException<ProblemDetails>` avec `Response = string.Empty`. Le `detail` n'est donc **pas** dans `apiException.Response` : il est exposé via `ApiException<ProblemDetails>.Result.Detail`. Le translator doit inspecter le type typé en priorité, et retomber sur le parsing de `Response` pour les statuts sans branche typée (`404`/`409` passent par la branche « else » de NSwag qui, elle, remplit `Response`).

```csharp
internal static class ApiExceptionTranslator
{
    public static Exception Traduire(ApiException apiException)
    {
        if (EstStatutMetier(apiException.StatusCode)
            && TryExtraireDetail(apiException, out var detail))
        {
            return new ErreurMetierGateway(detail);
        }

        return new ErreurTechniqueGateway(
            "Une erreur technique est survenue. Réessayez plus tard.",
            apiException);
    }

    private static bool TryExtraireDetail(ApiException apiException, out string detail)
    {
        if (apiException is ApiException<ProblemDetails> typed
            && !string.IsNullOrWhiteSpace(typed.Result?.Detail))
        {
            detail = typed.Result!.Detail!;
            return true;
        }
        return TryLireProblemDetails(apiException.Response, out detail);
    }

    private static bool EstStatutMetier(int statut) =>
        statut is 400 or 404 or 409;

    private static bool TryLireProblemDetails(string? response, out string detail)
    {
        detail = string.Empty;
        if (string.IsNullOrWhiteSpace(response)) return false;

        try
        {
            using var doc = JsonDocument.Parse(response);
            if (doc.RootElement.TryGetProperty("detail", out var d)
                && d.ValueKind == JsonValueKind.String
                && !string.IsNullOrWhiteSpace(d.GetString()))
            {
                detail = d.GetString()!;
                return true;
            }
        }
        catch (JsonException) { /* fallback technique */ }

        return false;
    }
}
```

Usage dans un Gateway :

```csharp
public async Task<Xxx> FaireAsync(...)
{
    try
    {
        return await _client.XxxAsync(...);
    }
    catch (ApiException ex)
    {
        throw ApiExceptionTranslator.Traduire(ex);
    }
}
```

## Règle Presenter

Tout Presenter qui appelle un Gateway DOIT traiter les deux exceptions typées explicitement :

```csharp
try
{
    await _gateway.FaireXxxAsync(...);
    Etat = EtatChargement.Charge;
}
catch (ErreurMetierGateway ex)
{
    Etat = EtatChargement.EnErreur;
    MessageErreur = ex.Message;
    _notifications.NotifierErreur(ex.Message);
}
catch (ErreurTechniqueGateway ex)
{
    Etat = EtatChargement.EnErreur;
    MessageErreur = ex.Message;
    _notifications.NotifierErreur(ex.Message);
}
```

Le Presenter injecte `INotificationService` (port défini dans `UI.Domain/Ports/`). L'adapter Radzen (`RadzenNotificationService`) est enregistré `Scoped` dans la composition root et pilote le `NotificationService` Radzen via le wrapper Kit `Notifications.razor` monté une fois dans `MainLayout`.

## Ce qui est interdit

- `catch (Exception ex)` générique dans un Presenter ou un Gateway.
- Utiliser `ex.Message` sur une `ApiException` NSwag brute (donne `"Response status code does not indicate success. (400)"`).
- Retourner `Result<T>` depuis un Gateway (→ réservé aux Field Presenters, cf. `blazor-hexagonal-frontend.md`).
- Afficher le `Message` d'une `ErreurTechniqueGateway.InnerException` à l'utilisateur.
- Instancier `ErreurMetierGateway` / `ErreurTechniqueGateway` ailleurs que dans `ApiExceptionTranslator` (sauf Fakes de test).

## Tests

Les Fake Gateways exposent une API fluide pour simuler chaque cas :

- `QuiEchoueMetier(string message)` → throw `new ErreurMetierGateway(message)`
- `QuiEchoueTechnique()` → throw `new ErreurTechniqueGateway("...", new Exception("simulée"))`

Tests Presenter attendus :
- Cas métier : assert `Etat == EnErreur`, `MessageErreur == "<message métier>"`, `FakeNotifications.DerniereErreur == "<message métier>"`.
- Cas technique : assert `Etat == EnErreur`, `MessageErreur` == libellé générique.
