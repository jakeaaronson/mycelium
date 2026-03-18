# Playbook: Testing

## Test Framework

- xUnit with `ITestOutputHelper` for logging
- Test fakes in `test_fakes/` folder (NOT mocking frameworks like Moq)
- Traits: `[Trait("Category", "Unit")]` or `[Trait("Category", "Integration")]`
- Helpers: `TestHelpers.cs`, `MoreAssert.cs`, `FakeEmailService`, `FakeUserStore` in `activecomply.common.tests`

## Writing Integration Tests

1. Seed expectation data in Elasticsearch
2. Reference pattern: `src/activecomply.common.tests/services/AccountServiceTests.cs`
3. Test against the **service** class (not controller)
4. ES test client connects to `localhost:9200`
5. Generate unique strings: `"account-" + TestHelpers.GenerateRandomString()`

## Running Tests

```bash
dotnet test activecomply.sln                    # All tests
dotnet test profiles.sln                        # All profiles tests
dotnet test path/to/project.csproj              # One project
dotnet test path/to.csproj --filter "FullyQualifiedName=NS.Class.Method"  # One test
```

Always specify `.csproj` path to avoid "multiple project" errors.

## When Controller Tests Are Needed

Only for exceptional cases. Use `WebApplicationFactory` and mock all dependencies. Keep concise.

## Common Mistakes

- Using Moq → Use test fakes instead
- Testing controllers by default → Test services
- Forgetting `[Trait("Category", ...)]` → Always tag tests
- Not seeding ES data first → Integration tests need data
