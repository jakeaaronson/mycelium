# Playbook: Lambda Development

## Current Lambdas

| Lambda | Purpose | Trigger |
|--------|---------|---------|
| response-processor | Parse emails, score, create threads | SQS (from SES→SNS) |
| email-dispatcher | Send confirmation/notification emails | Direct invoke |
| ui-index-rebuilder | Rebuild index.json from DynamoDB | EventBridge (every 60s) |
| vector-embedder-builder | Embeddings, coordinates, category tree | EventBridge (daily 4am UTC) |
| email-test | Test email send | Manual invoke |

## Adding a New Lambda

1. Create `lambdas/{lambda-name}/` directory
2. Create `index.ts` with handler export
3. Create `tsconfig.json` extending `../../tsconfig.base.json`
4. Add build script to `package.json`
5. Add typecheck to `package.json` typecheck script
6. Add to CloudFormation `infrastructure/template.yaml`
7. Update `PROJECT_SPEC.md` Architecture section

## Testing a Lambda

```bash
# Invoke directly
aws lambda invoke --function-name community-{name}-dev /dev/stdout

# With payload
aws lambda invoke --function-name community-vector-embedder-builder-dev \
  --payload '{"threadIds":["thread-1"]}' /dev/stdout
```

## Build

```bash
node esbuild.config.mjs   # Builds all lambdas to dist/
```

## Deploy Cycle

1. Make changes → `npm run build` → `npm test`
2. `git push origin main` → GitHub Actions deploys
3. Check build: `gh run list --limit 3`
4. If green and seeds needed: run seed scripts
5. Verify on live site
