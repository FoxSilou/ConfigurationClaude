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

### WebApplicationFactory

Each test class has its own factory instance. The database is reset between tests via TestContainers container restart or schema reset.

```csharp
public class PartieApiTests : IAsyncLifetime
{
    private WebApplicationFactory<Program> _factory = null!;
    private HttpClient _client = null!;

    public async Task InitializeAsync()
    {
        _factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.ConfigureServices(services =>
                {
                    // Replace real DB with TestContainers connection
                    services.RemoveAll<DbContextOptions<AppDbContext>>();
                    services.AddDbContext<AppDbContext>(options =>
                        options.UseNpgsql(TestDatabase.ConnectionString));
                });
            });

        _client = _factory.CreateClient();
        await TestDatabase.ResetAsync();
    }

    public async Task DisposeAsync()
    {
        _client.Dispose();
        await _factory.DisposeAsync();
    }
}
```

### TestContainers — Shared Container

The database container is shared across the test session (started once) but the schema is reset between each test class:

```csharp
public static class TestDatabase
{
    private static readonly PostgreSqlContainer _container = new PostgreSqlBuilder()
        .WithDatabase("testdb")
        .WithUsername("test")
        .WithPassword("test")
        .Build();

    public static string ConnectionString => _container.GetConnectionString();

    public static async Task StartAsync() => await _container.StartAsync();
    public static async Task StopAsync() => await _container.StopAsync();

    public static async Task ResetAsync()
    {
        // Drop and recreate schema, or use Respawn
        using var scope = /* get service scope */;
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        await context.Database.EnsureDeletedAsync();
        await context.Database.EnsureCreatedAsync();
    }
}
```

Start and stop the container via `AssemblyFixture` or `CollectionFixture`:

```csharp
[CollectionDefinition("E2E")]
public class E2ECollection : ICollectionFixture<E2EFixture> { }

public class E2EFixture : IAsyncLifetime
{
    public Task InitializeAsync() => TestDatabase.StartAsync();
    public Task DisposeAsync() => TestDatabase.StopAsync();
}
```

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

