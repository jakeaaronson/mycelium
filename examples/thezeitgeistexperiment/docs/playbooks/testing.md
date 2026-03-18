# Playbook: Testing (Zeitgeist)

## Unit Tests

```bash
npm test          # Vitest
```

## Integration Tests

```bash
INTEGRATION=true vitest run   # Hits real Bedrock + S3 Vectors
```

Integration tests are NOT run in normal CI. They require AWS credentials.

## Smoke Tests

Script exercises full email flow with settings changes. Located in `scripts/`.

## Regression Tests

AI-generated reports using himalaya CLI for email send/receive verification. Gmail test account credentials at `~/inkmans_brain`.

## Visual Testing (Ralph Wiggum Technique)

Iterative Puppeteer screenshot loop for UI testing:
1. Take screenshot of live site
2. Review visually
3. Make change
4. Screenshot again
5. Compare

Tests use live URL (data in S3/CloudFront), not local server.

## CI Pipeline

GitHub Actions runs: build → typecheck → tests → `docs:emails:check` → deploy

The `docs:emails:check` step verifies auto-generated email docs are current. Run `npm run docs:emails` locally to regenerate.
