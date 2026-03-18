# Playbook: Deployment & Infrastructure

## Check Latest Deployment

```bash
# Latest release
gcloud deploy releases list \
  --delivery-pipeline=activecomply-api \
  --region=us-central1 \
  --project=activecomply-app-dev \
  --limit=1 --format="value(name)"

# Release details
gcloud deploy releases describe <release-name> \
  --delivery-pipeline=activecomply-api \
  --region=us-central1 --project=activecomply-app-dev
```

## Kubernetes (VPN Required)

```bash
# Connect to test cluster
gcloud container clusters get-credentials activecomply-dev \
  --zone us-central1-a --project activecomply-app-dev --internal-ip

# Pods, logs, describe
kubectl get pods -n test
kubectl logs -n test <pod-name>
kubectl describe pod -n test <pod-name>
```

If kubectl fails with timeout → user needs to connect to VPN first.

## Environments

| Env | GCP Project | K8s Cluster | K8s Namespace |
|-----|------------|-------------|---------------|
| Test | `activecomply-app-dev` | `activecomply-dev` (us-central1-a) | `test` |
| Prod | `activecomply-app` | `activecomply-prod` (us-central1-a) | default |
| Prod workflows | `activecomply-app` | `ac` (us-central1, regional) | default |

## After Merge

1. Allow time for Cloud Build + deployment
2. Check deployment timestamps to verify your code is included
3. Monitor pod rollout: `kubectl get pods -n test -w`
