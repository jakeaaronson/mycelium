# CLAUDE.md

**.NET 8 compliance API** — Social media monitoring, document reviews, and compliance workflows for financial services. Two solutions: `activecomply.sln` (main) and `profiles.sln` (social monitoring, GraphQL).

## Hard Rules

2. **Namespace separation** — `activecomply.sln` NEVER references `profiles.*` namespaces (except `activecomply.common`). `profiles.sln` may reference `activecomply.*`.
3. **No commits unless asked** — Never run `git add` or `git commit` without explicit user request.
4. **LF line endings** — Enforced via `.gitattributes`. All new files must use LF.
5. **Minimal code** — Write only what's needed. No speculative features, no over-engineering.
6. **Branch from `development`** — Never branch from `main`. Branch naming: `DEV-{ticket}-{kebab-case}`.

## Build & Test

```
dotnet build activecomply.sln          # Main solution
dotnet build profiles.sln              # Profiles solution
dotnet test activecomply.sln           # All main tests
dotnet test profiles.sln               # All profiles tests
dotnet test path/to.csproj --filter "FullyQualifiedName=NS.Class.Method"  # Single test
```

Fast rebuild: `dotnet build activecomply.sln --no-restore --verbosity quiet`

## Before You Start

| Task | Read First |
|------|-----------|
| Elasticsearch work (queries, reindex, templates) | `docs/playbooks/elasticsearch.md` |
| Writing or running tests | `docs/playbooks/testing.md` |
| Checking deployments or K8s | `docs/playbooks/deployment.md` |
| Git branching, commits, or PRs | `docs/playbooks/git-workflow.md` |
| Temporal workflows | `docs/playbooks/temporal.md` |
| Working across multiple repos | `docs/playbooks/multi-repo.md` |

## Key Constants

- **Atlassian Cloud ID**: `559a76c5-7f47-4832-ab40-bd6462c90c6c`
- **GCP Test Project**: `activecomply-app-dev`
- **GCP Prod Project**: `activecomply-app`
- **ES API Key Location**: `src/activecomply.cli/appsettings.Development.json` → `Elasticsearch.ApiKey`
- **ES Cached Key**: `.claude/elasticsearch-key.local.json`
- **Base branch**: `development`

## Do Not

- Use CDK or Terraform (we use CloudFormation for zeitgeist, Kustomize for ActiveComply)
- Add mocking frameworks like Moq — use xUnit patterns and test fakes
- Use `profiles/elasticsearch/` templates (legacy) — use `elasticsearch/templates/`
- Reference `profiles.*` namespaces from `activecomply.sln` projects
