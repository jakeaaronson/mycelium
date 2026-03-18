# Playbook: Seed Data & Reindexing

## Seed Scripts

```bash
# Short topics (300 one-liners)
npm run seed:topics [--dry-run] [--delay <ms>]

# Short responses (embedding-matched)
npm run seed:responses [--dry-run] [--delay <ms>]

# Long topics (100 essay-length)
npm run seed:long-topics [--dry-run] [--delay <ms>]

# Long responses (text-matched)
npm run seed:long-responses [--dry-run] [--delay <ms>]

# Generate new responses via Claude API
ANTHROPIC_API_KEY=sk-... npm run seed:generate
ANTHROPIC_API_KEY=sk-... npm run seed:generate-long
ANTHROPIC_API_KEY=sk-... npm run seed:generate-long-responses
```

## Reindex / Re-embed

```bash
# Full reindex (all threads + category tree)
aws lambda invoke --function-name zeitgeist-vector-embedder-builder-dev --payload '{}' /dev/stdout

# Specific threads only (no category rebuild)
aws lambda invoke --function-name zeitgeist-vector-embedder-builder-dev \
  --payload '{"threadIds":["thread-id-1","thread-id-2"]}' /dev/stdout
```

## After Model/Scoring Changes

1. Delete old event bucket data (if needed)
2. Run seed scripts
3. Check topic count (should be ~300, not ~80)
4. Run reindex lambda
5. Verify on live site

## Common Mistake

DUPLICATE_THRESHOLD too low → collapses unique topics. Each seed topic IS intentionally different. If topics are being collapsed, raise the threshold, don't assume duplicates.
