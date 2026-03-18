# Reference: Project Structure

## Key Paths

| Path | Purpose |
|------|---------|
| `website/index.html` | Entire frontend (~1800 lines, canvas bubble map, all inline) |
| `lambdas/response-processor/` | Core backend (email-parser.ts, response-path.ts, topic-path.ts, embeddings.ts, user-ops.ts) |
| `lambdas/email-dispatcher/index.ts` | Email templates and sending |
| `lambdas/ui-index-rebuilder/` | Rebuilds public index.json (EventBridge, 60s) |
| `lambdas/vector-embedder-builder/` | Embeddings, coordinates, category tree (daily) |
| `infrastructure/template.yaml` | CloudFormation/SAM template |
| `infrastructure/claude-seed-policy.json` | IAM policy (manual console paste) |
| `known-bugs/` | Numbered bug reports (001-008+) |
| `docs/generated/email-system.md` | Auto-generated email docs (`npm run docs:emails`) |
| `scripts/seed/` | Seed data scripts and JSON files |
| `brainstorm/` | Old spec, question lists, email samples |

## Frontend Architecture

Single `website/index.html` with:
- Canvas rendering loop with bubble physics (position lerping, alpha transitions)
- Camera system (camX/camY, targetCamX/targetCamY, detailLevel)
- Bubble state machine (layout targets, search alpha, fade states)
- All CSS and JS inline — no component system, no build pipeline for frontend
- Modifications require editing this monolithic file

## Build

```bash
node esbuild.config.mjs    # Builds all lambdas to dist/
npm run build               # Full build (includes typecheck)
```

## CloudFormation

```yaml
# YAML only, not JSON
# Logical IDs in PascalCase
# Descriptions on all resources
# !Ref and !GetAtt over hardcoded values
```

Template: `infrastructure/template.yaml`
Validate: `aws cloudformation validate-template --template-body file://infrastructure/template.yaml`
