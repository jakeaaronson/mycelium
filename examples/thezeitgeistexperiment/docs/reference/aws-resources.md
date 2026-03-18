# Reference: AWS Resources

## Region: us-east-1

## Lambda Functions

| Function | Purpose | Trigger |
|----------|---------|---------|
| `zeitgeist-response-processor-dev` | Parse inbound emails, score responses, manage threads | SQS |
| `zeitgeist-email-dispatcher-dev` | Send confirmation/notification emails | Direct invoke |
| `zeitgeist-ui-index-rebuilder-dev` | Rebuild public index.json from DynamoDB | EventBridge (60s) |
| `zeitgeist-vector-embedder-builder-dev` | Embeddings, coordinates, category tree | EventBridge (daily 4am UTC) |
| `zeitgeist-email-test-dev` | Test email sending | Manual invoke |
| `zeitgeist-bedrock-test-dev` | Test Bedrock integration | Manual invoke |

## S3 Buckets

| Bucket | Access | Content |
|--------|--------|---------|
| `zeitgeist-website-{env}-{accountId}` | Private (CloudFront OAC) | Static HTML/CSS/JS |
| `zeitgeist-public-{accountId}` | Private (CloudFront OAC) | index.json, categories.json, threads/*.json, users/*.json |
| `zeitgeist-events-{accountId}` | Private (Lambda only, deny-delete) | Immutable event log: `events/{date}/{timestamp}_{id}.json` |
| `zeitgeist-vectors-dev` | Private | Vector embeddings index |

## DynamoDB Tables

| Table | PK | Purpose |
|-------|-----|---------|
| `zeitgeist-threads-{env}` | `thread_id` (S) | Thread metadata — source of truth for index.json |
| `zeitgeist-profiles-{env}` | `email_hash` (S) | User profiles with email addresses |

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
| `*@thezeitgeistexperiment.com` | Inbound (SES receiving) |
| `thezeitgeistbot@thezeitgeistexperiment.com` | Outbound sender |
| `albert.g.inkman@gmail.com` | AI seed user |
| `jakeaaronson@gmail.com` | Owner |

## Email Notification Types

1. `question_live` — Your topic is now live
2. `new_response` — Someone responded to your topic
3. `ranking_confirmation` — Your response was ranked
4. `settings` — Settings/preferences changes

## IAM

- `claude-readonly` user — managed manually in AWS console (NOT CloudFormation)
- Policies: `ZeitgeistReadOnly` + `claude-seed-policy`
- Policy JSON: `infrastructure/claude-seed-policy.json` (paste into console manually)
- When permission denied: report exact action + resource → user adds in console
