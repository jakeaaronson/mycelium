# Playbook: Elasticsearch

## Credentials

1. Check `.claude/elasticsearch-key.local.json` for cached base64 key
2. If missing: read `src/activecomply.cli/appsettings.Development.json` → `Elasticsearch.ApiKey` (Id + Key)
3. Create: `echo -n "API_KEY_ID:API_KEY" | base64`
4. Cache it: `{"encoded_key": "BASE64_STRING"}` in `.claude/elasticsearch-key.local.json`

## Querying

```bash
# Search
curl -X GET "localhost:9200/{index}/_search?size=10&pretty" \
  -H 'Content-Type: application/json' \
  -H 'Authorization: ApiKey <BASE64_KEY>'

# Count
curl -X GET "localhost:9200/{index}/_count?pretty" \
  -H 'Authorization: ApiKey <BASE64_KEY>'

# Update by query
curl -X POST "localhost:9200/{index}/_update_by_query?refresh=true&pretty" \
  -H 'Content-Type: application/json' \
  -H 'Authorization: ApiKey <BASE64_KEY>' \
  -d '{"script":{"source":"ctx._source.field = params.val","lang":"painless","params":{"val":"new"}},"query":{"term":{"status":"active"}}}'
```

Common indices: `monitored_profiles`, `linkedin_posts`, `social_profiles`

## Reindexing

1. Create temp index with `reindex_` prefix (avoids template pattern matches)
2. `POST _reindex` source → `reindex_{name}`
3. Delete original index
4. `POST _reindex` `reindex_{name}` → original name
5. Delete temp index

## Templates

- Location: `elasticsearch/templates/` (NOT `profiles/elasticsearch/` — that's legacy)
- Extension: `.es` with plural index names (e.g., `accounts.es`)
- Always set `dynamic: false`, use `keyword` for IDs, `date` for timestamps
- Use `composed_of: ["data_content"]` or `["data_content", "lowercase_keyword_normalizer"]`
- All field names are **camelCase** (not snake_case) — matches C# JSON serialization

See `docs/reference/es-conventions.md` for full template conventions.
