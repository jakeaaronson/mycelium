# Reference: AWS Resources

## Region: us-east-1

## Lambda Functions

| Function | Purpose | Trigger |
|----------|---------|---------|
| `community-response-processor-dev` | Parse inbound emails, score responses, manage threads | SQS |
| `community-email-dispatcher-dev` | Send confirmation/notification emails | Direct invoke |
| `community-ui-index-rebuilder-dev` | Rebuild public index.json from DynamoDB | EventBridge (60s) |
| `community-vector-embedder-builder-dev` | Embeddings, coordinates, category tree | EventBridge (daily 4am UTC) |
| `community-email-test-dev` | Test email sending | Manual invoke |
| `community-bedrock-test-dev` | Test Bedrock integration | Manual invoke |

## S3 Buckets

| Bucket | Access | Content |
|--------|--------|---------|
| `community-website-{env}-{accountId}` | Private (CloudFront OAC) | Static HTML/CSS/JS |
| `community-public-{accountId}` | Private (CloudFront OAC) | index.json, categories.json, threads/*.json, users/*.json |
| `community-events-{accountId}` | Private (Lambda only, deny-delete) | Immutable event log: `events/{date}/{timestamp}_{id}.json` |
| `community-vectors-dev` | Private | Vector embeddings index |

## DynamoDB Tables

| Table | PK | Purpose |
|-------|-----|---------|
| `community-threads-{env}` | `thread_id` (S) | Thread metadata — source of truth for index.json |
| `community-profiles-{env}` | `email_hash` (S) | User profiles with email addresses |

## Email Pipeline

```
Inbound email → SES → SNS → SQS → response-processor Lambda
  → DynamoDB (threads/profiles)
  → S3 (thread JSON, event log)
  → email-dispatcher Lambda (confirmations)
```

## Email Addresses

| Address | Purpose |
|---------|---------|
| `*@community-platform.example.com` | Inbound (SES receiving) |
| `platformbot@community-platform.example.com` | Outbound sender |
| `seedbot@example.com` | AI seed user |
| `owner@example.com` | Owner |

## Email Notification Types

1. `question_live` — Your topic is now live
2. `new_response` — Someone responded to your topic
3. `ranking_confirmation` — Your response was ranked
4. `settings` — Settings/preferences changes

## IAM

- `claude-readonly` user — managed manually in AWS console (NOT CloudFormation)
- Policies: `CommunityPlatformReadOnly` + `claude-seed-policy`
- Policy JSON: `infrastructure/claude-seed-policy.json` (paste into console manually)
- When permission denied: report exact action + resource → user adds in console
