# Playbook: AWS Infrastructure

## CloudFormation

All infrastructure is in `infrastructure/template.yaml`. YAML only, not JSON.

```bash
# Validate
aws cloudformation validate-template --template-body file://infrastructure/template.yaml

# Deploy
aws cloudformation deploy \
  --template-file infrastructure/template.yaml \
  --stack-name community-dev \
  --capabilities CAPABILITY_NAMED_IAM
```

Naming conventions: Logical IDs in PascalCase, descriptions on all resources, `!Ref` and `!GetAtt` over hardcoded values.

## IAM

- `claude-readonly` user — managed **manually in AWS console** (NOT in CloudFormation)
- Policies: `CommunityPlatformReadOnly` + `claude-seed-policy`
- Policy JSON source: `infrastructure/claude-seed-policy.json`
- To update: edit the JSON, paste into AWS console manually

When a permission error occurs: report the exact action and resource denied. The user adds it manually.

## Adding AWS Resources

1. Add to `infrastructure/template.yaml`
2. Validate template
3. Deploy via CloudFormation or push (GitHub Actions deploys)
4. Update PROJECT_SPEC.md Architecture section
5. If new S3 bucket: document in S3 Buckets table

## Checking Resources

```bash
# Lambda logs
aws logs tail /aws/lambda/community-{name}-dev --follow

# S3 contents
aws s3 ls s3://community-public-{accountId}/

# DynamoDB scan
aws dynamodb scan --table-name community-threads-dev --max-items 5

# SQS queue depth
aws sqs get-queue-attributes --queue-url {url} --attribute-names ApproximateNumberOfMessages
```

## Do Not

- Use CDK or Terraform — CloudFormation only
- Modify IAM via CloudFormation — it's manual
- Add resources without updating PROJECT_SPEC.md
