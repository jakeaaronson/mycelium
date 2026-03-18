# Reference: Code Style (C# / .NET)

## Language Features

- C# 10+ with nullable reference types enabled
- File-scoped namespaces
- `activecomply.*` prefix for all namespaces
- String interpolation over concatenation
- `ArgumentNullException.ThrowIfNull()` for null checks
- ReadOnlySpan<char> for performance-sensitive string operations
- Generic collections + LINQ for data manipulation

## Conventions

- **Enums**: Always decorate with `[JsonConverter(typeof(StringEnumConverter))]`
- **DI**: New services must be registered in `Program.cs` (`services.AddTransient<IService, ServiceImpl>()`)
- **Extensions**: Place in `activecomply.extensions` namespace
- **Class layout**: Public methods first, private methods at bottom, grouped by functionality

## Namespace Separation

```
activecomply.sln          profiles.sln
  ├── activecomply.*        ├── profiles.*
  ├── can use common        ├── can use activecomply.*
  └── CANNOT use profiles.* └── profiles.api uses GraphQL (NOT REST)
```

Shared code goes in `activecomply.common`. If profiles-specific code is needed in activecomply, create a duplicate in the activecomply namespace.

## API Routing

- **No `/api/` prefix** — Controllers use `[Route("[controller]")]`
- URLs are lowercase (configured in `RouteConfiguration.cs`)
- Example: `DocReviewsController` → `GET /docreviews/{id}`

## Profiles Solution Specifics

- **GraphQL only** (NOT REST) — no traditional controllers in `profiles.api`
- Schema: `profiles.graphql`, centralized `Mutations.cs` (~101K LOC)
- Uses **Google Pub/Sub** for messaging (not Temporal)
- Graph data model: `Node`, `GraphService`, `GraphRepo`
