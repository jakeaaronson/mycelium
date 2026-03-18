# CLAUDE.md

**The Zeitgeist Experiment** — A living repository of collective opinion. Users email responses to topic bubbles, AI scores and ranks them. No accounts, no feeds, no likes. Email is the primary entry point.

Domains: `thezeitgeistexperiment.com`, `zeitgeistexperiment.com` (redirects)

## Stack

- **Language:** TypeScript, Node.js 22.x
- **Infra:** AWS (Lambda, S3, SQS, SES, EventBridge, CloudFront, DynamoDB)
- **IaC:** CloudFormation (NOT CDK, NOT Terraform)
- **AI:** Claude via Amazon Bedrock for scoring, summarization, moderation
- **CI/CD:** GitHub Actions → deploy to AWS

## Hard Rules

1. **CloudFormation only** — No CDK, no Terraform
2. **Plain text email** — No HTML emails (deliberate design choice)
3. **Anti-convention design is intentional** — Serif fonts, no color, no buttons, no tracking. Do not "fix" these.
4. **No API Gateway** — Website reads static JSON from S3 via CloudFront
5. **Node.js 22.x minimum** — Don't use older runtimes
6. **Git: push to main** — No feature branches. Ship directly to main.

## Build & Deploy

```
npm install && npm run build && npm test
git push origin main                    # Triggers GitHub Actions deploy
```

Manual CloudFormation: `aws cloudformation deploy --template-file infrastructure/template.yaml --stack-name zeitgeist-dev --capabilities CAPABILITY_NAMED_IAM`

## Before You Start

| Task | Read First |
|------|-----------|
| Lambda changes or new Lambda | `docs/playbooks/lambda-workflow.md` |
| Seeding or reindexing data | `docs/playbooks/seed-reindex.md` |
| Email flow changes | `docs/playbooks/email-system.md` |
| Running tests | `docs/playbooks/testing.md` |
| AWS infrastructure changes | `docs/playbooks/aws-infra.md` |
| Frontend / bubble map changes | `docs/playbooks/frontend.md` |

## Key Documentation

- `PROJECT_SPEC.md` — Technical specification (keep updated)
- `known-bugs/` — Numbered bug reports with status
- `docs/generated/email-system.md` — Auto-generated (run `npm run docs:emails`)

## AWS Access

IAM user `claude-readonly` with `ZeitgeistReadOnly` + `claude-seed-policy`. Region: `us-east-1`. When permission denied: tell user the exact action/resource — they add it manually in console.

## Do Not

- Add accent colors, gradients, or decorative elements
- Create APIs for reading thread data (that's direct S3 via CloudFront)
- Add npm packages without considering Lambda bundle size
- Implement outbound email question distribution (post-MVP)
