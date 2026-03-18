# Reference: Elasticsearch Conventions

## Index Template Conventions

- **Location**: `elasticsearch/templates/` (NOT `profiles/elasticsearch/` — legacy)
- **File extension**: `.es` with plural index names (e.g., `accounts.es`, `docreviews.es`)
- **Never** use `-template` suffix (e.g., ~~`account-template.json`~~)

### Template Structure

```json
POST _index_template/{template_name}
{
  "index_patterns": ["template_name*"],
  "composed_of": ["data_content"],
  "template": {
    "mappings": {
      "dynamic": false,
      "properties": {
        "id": { "type": "keyword" },
        "accountId": { "type": "keyword" },
        "created": { "type": "date" },
        "updated": { "type": "date" },
        "status": { "type": "keyword" },
        "isActive": { "type": "boolean" },
        "count": { "type": "integer" }
      }
    }
  }
}
```

### Field Type Rules

| Use Case | Type | Notes |
|----------|------|-------|
| IDs, enums, exact match | `keyword` | |
| Timestamps | `date` | |
| True/false | `boolean` | |
| Counters | `integer` | |
| Sensitive data (tokens, passwords) | keyword + `"index": false` | Prevents indexing |

### Naming

- **All field names are camelCase** — matches C# JSON serializer output
  - `accountId` NOT `account_id`
  - `requiresHumanApproval` NOT `requires_human_approval`
  - `updatedAt` NOT `updated_at`
- Always set `dynamic: false` to prevent automatic field mapping
- Use `composed_of: ["data_content"]` or `["data_content", "lowercase_keyword_normalizer"]`

## Common Indices

| Index | Purpose |
|-------|---------|
| `monitored_profiles` | Social media profiles under compliance monitoring |
| `linkedin_posts` | Archived LinkedIn posts |
| `social_profiles` | Social media profile metadata |

## Reindex Naming

Temporary indices during reindex MUST use `reindex_` prefix:
- `reindex_platform_usertokens` (temp) → `platform_usertokens` (final)
- Reason: `reindex_` prefix won't match template patterns, avoiding automatic field analysis on temp data
