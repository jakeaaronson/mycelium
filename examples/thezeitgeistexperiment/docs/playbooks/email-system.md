# Playbook: Email System

## Inbound Flow

```
User sends email → SES receives → SNS notification → SQS queue → response-processor Lambda
```

Email address determines routing:
- `{thread-id}@thezeitgeistexperiment.com` → thread response handler
- `thezeitgeistbot@...` → new topic submission

## Outbound Notifications

4 types:
1. `question_live` — Your topic is now live
2. `new_response` — Someone responded to your topic
3. `ranking_confirmation` — Your response was ranked
4. `settings` — Settings/preferences changes

Sent via `email-dispatcher` Lambda. **Plain text only** — no HTML emails (deliberate design choice).

## Key Constants

| Constant | Location | Purpose |
|----------|----------|---------|
| `FROM_ADDRESS` | response-processor | Outbound sender address |
| `SITE_URL` | response-processor | Link base in emails |
| `DOMAIN` | response-processor | Email domain |
| `IGNORE_ADDRESSES` | response-processor | Addresses to skip |
| `DUPLICATE_THRESHOLD` | response-processor | Similarity cutoff for dedup |

## Regenerating Email Docs

```bash
npm run docs:emails          # Regenerate docs/generated/email-system.md
npm run docs:emails:check    # CI mode — fails if docs are stale
```

The generator reads 6 source files via regex and produces markdown. Run after any email flow change.

## Changing Email Templates

Edit in `lambdas/email-dispatcher/`. Update PROJECT_SPEC.md Email Flows section if structure changes.

## Common Issues

- Notification throttle in `response-path.ts` — may suppress expected emails
- SES receiving rules only process `@thezeitgeistexperiment.com` domain
- SNS topic connects SES to SQS — check SNS subscriptions if emails aren't processing
