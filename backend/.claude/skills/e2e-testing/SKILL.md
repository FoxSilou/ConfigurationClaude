---
name: e2e-testing
description: >
  E2E testing conventions for the backend HTTP API.
  Use when writing, reviewing, or discussing end-to-end tests that exercise
  the system through its HTTP interface. Covers: black-box testing via
  POST then GET, WebApplicationFactory setup, TestContainers for database,
  status code and DTO assertions, and test file organization.
user-invocable: false
---


# Skill: E2E Testing

## Philosophy

E2E tests verify the system **from the outside**, through its HTTP interface. They treat the application as a black box — no knowledge of internal structure, domain objects, or database state.

### Core Principles

- **Act** via a state-changing HTTP call (POST, PUT, PATCH, DELETE).
- **Assert** via a subsequent HTTP GET — verify what the API exposes, nothing else.
- Never query the database directly in assertions.
- Never access domain objects or repositories in tests.
- E2E tests cover **critical paths only** — not every scenario. Edge cases belong to unit tests.

---

## Test Structure — Arrange / Act / Assert

```csharp
[Fact]
public async Task CreerPartie_doit_etre_accessible_apres_creation()
{
    // Arrange
    var payload = new { Nom = "Championnat de France" };

    // Act
    var createResponse = await _client.PostAsJsonAsync("/api/parties", payload);
    createResponse.StatusCode.Should().Be(HttpStatusCode.Created);
    var location = createResponse.Headers.Location!.ToString();

    // Assert
    var getResponse = await _client.GetAsync(location);
    getResponse.StatusCode.Should().Be(HttpStatusCode.OK);

    var partie = await getResponse.Content.ReadFromJsonAsync<PartieDto>();
    partie!.Nom.Should().Be("Championnat de France");
}
```

### Rules

- **Arrange**: prepare the HTTP payload only. No domain objects, no repository setup.
- **Act**: one state-changing HTTP call. Assert its status code immediately (`201 Created`, `200 OK`…).
- **Assert**: one HTTP GET on the affected resource. Assert on the response body (deserialized DTO).
- One test = one critical path. Do not chain multiple state-changing calls in a single test.

---

## Naming Convention

Same pattern as unit tests, scoped to the HTTP scenario:

```
<Endpoint>_doit_<resultat_attendu>_quand_<contexte>
```

```
CreerPartie_doit_etre_accessible_apres_creation
CreerPartie_doit_retourner_400_quand_le_nom_est_vide
ObtenirPartie_doit_retourner_404_quand_la_partie_est_introuvable
```

---

## Infrastructure Setup

### WebApplicationFactory with Testcontainers SQL Server

The test factory extends `WebApplicationFactory<Program>` and uses **Testcontainers SQL Server** for full database isolation. A single container is shared across the test session via `ICollectionFixture`.

> **⚠️ xUnit 2.9.x** : `IAsyncLifetime.InitializeAsync()` et `DisposeAsync()` retournent **`Task`**, PAS `ValueTask`. `ValueTask` est xUnit v3 uniquement — ce projet utilise xUnit 2.9.x.

```csharp
public sealed class ImperiumRexWebApplicationFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly MsSqlContainer _sqlContainer = new MsSqlBuilder("mcr.microsoft.com/mssql/server:2022-latest")
        .Build();

    public FakeTimeProvider FakeTimeProvider { get; } = new();

    public async Task InitializeAsync()
    {
        await _sqlContainer.StartAsync();
        EnsureDatabaseCreated();
    }

    public new async Task DisposeAsync()
    {
        await _sqlContainer.DisposeAsync();
        await base.DisposeAsync();
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        builder.ConfigureServices(services =>
        {
            // Replace TimeProvider
            var timeDesc = services.SingleOrDefault(d => d.ServiceType == typeof(TimeProvider));
            if (timeDesc is not null) services.Remove(timeDesc);
            services.AddSingleton<TimeProvider>(FakeTimeProvider);

            // Replace WriteDbContext → Testcontainers SQL Server
            var esDesc = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<WriteDbContext>));
            if (esDesc is not null) services.Remove(esDesc);
            services.AddDbContext<WriteDbContext>(options =>
                options.UseSqlServer(_sqlContainer.GetConnectionString()));

            // Replace ReadDbContext → Testcontainers SQL Server
            var readDesc = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<ReadDbContext>));
            if (readDesc is not null) services.Remove(readDesc);
            services.AddDbContext<ReadDbContext>(options =>
                options.UseSqlServer(_sqlContainer.GetConnectionString()));
        });
    }

    private void EnsureDatabaseCreated()
    {
        using var scope = Services.CreateScope();
        scope.ServiceProvider.GetRequiredService<WriteDbContext>().Database.EnsureCreated();
        scope.ServiceProvider.GetRequiredService<ReadDbContext>().Database.EnsureCreated();
    }
}
```

### Collection Fixture

```csharp
[CollectionDefinition("E2E")]
public class E2ECollection : ICollectionFixture<ImperiumRexWebApplicationFactory> { }
```

### NuGet packages for E2E tests

- `Microsoft.AspNetCore.Mvc.Testing`
- `FluentAssertions`
- `Microsoft.Extensions.TimeProvider.Testing`
- `Testcontainers.MsSql`
- `xunit`

> `FakeTimeProvider` est dans le namespace `Microsoft.Extensions.Time.Testing` (différent du nom du package NuGet).

---

## Assertions

### Status codes

```csharp
response.StatusCode.Should().Be(HttpStatusCode.Created);
response.StatusCode.Should().Be(HttpStatusCode.OK);
response.StatusCode.Should().Be(HttpStatusCode.NotFound);
response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
```

### Response body

Always deserialize to a DTO — never assert on raw JSON strings:

```csharp
var dto = await response.Content.ReadFromJsonAsync<PartieDto>();
dto.Should().NotBeNull();
dto!.Nom.Should().Be("Championnat de France");
```

### What NOT to assert

- Database state directly (no `DbContext` in assertions)
- Internal domain object state
- Number of SQL queries executed
- Log output

---

## Test File Structure

```
tests/
└── E2E.Tests/
    ├── E2EFixture.cs              # Container lifecycle
    ├── TestDatabase.cs            # Reset logic
    └── Parties/
        └── PartieApiTests.cs      # One file per resource/feature
```

One test class per API resource or feature. All critical path scenarios for that resource live in the same file.

---

## Scope — When to Write E2E Tests

E2E tests are **not** written for every scenario. They cover:

- The **happy path** of each critical feature
- **Error responses** that matter to the client (404, 400 on invalid input)

Everything else (edge cases, domain invariants, validation details) is covered by unit tests.


---

