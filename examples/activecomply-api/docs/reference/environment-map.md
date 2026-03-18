# Reference: Environment Map

## Machines

```
jacob-main-mint (local dev — AMD Ryzen 7 7700X, 32GB DDR5, RTX 2060 SUPER)
  ├── ~/activecomply-api       .NET 8 backend
  ├── ~/dashboard-app          React frontend (EUI)
  ├── ~/survey-app             React survey app (Firebase)
  ├── ~/dev-agents             Multi-project orchestration
  ├── ~/developer_bootstrap    Docker Compose (ES, Redis, RabbitMQ, Temporal)
  ├── ~/thezeitgeistexperiment Personal project (AWS serverless)
  ├── ~/agentdepo              New product mockups
  ├── ~/inkmans_brain          Symlink → sshfs mount to agent-house
  └── ~/mnt/agent-house/...    sshfs mount (fragile, drops periodically)

192.168.1.101 (agent-house — remote Linux Mint)
  ├── ~/inkmans_brain/         Bot engine, prompts, scripts, creds
  ├── Chrome (Flatpak)         Browser automation
  └── Cron jobs per worker     inkman-bluesky, inkman-historian, etc.
```

## Local Docker Services (developer_bootstrap)

| Service | Port | Notes |
|---------|------|-------|
| Elasticsearch | 9200 | Password: letmein123 |
| Kibana | 5601 | |
| RabbitMQ Management | 15672 | |
| Redis | 6379 | |
| Temporal | 7233 | CLI: `docker exec temporal temporal ...` |

## Application Ports

| App | Port | Start Command |
|-----|------|--------------|
| Dashboard API (HTTP) | 5001 | `dotnet run --project src/activecomply.api.dashboard` |
| Dashboard API (HTTPS) | 7001 | Same with HTTPS redirect |
| Dashboard Frontend | 5173 | `cd ~/dashboard-app && yarn start` |
| Survey App | 3000 | `cd ~/survey-app/survey-app && npm start` |

## GCP Environments

| Env | Project ID | K8s Cluster | Zone | Namespace |
|-----|-----------|-------------|------|-----------|
| Test | `activecomply-app-dev` | `activecomply-dev` | `us-central1-a` | `test` |
| Prod | `activecomply-app` | `activecomply-prod` | `us-central1-a` | default |
| Prod (workflows) | `activecomply-app` | `ac` | `us-central1` (regional) | default |

## Credential Locations

| Credential | Location |
|-----------|----------|
| ES API Key | `src/activecomply.cli/appsettings.Development.json` → `Elasticsearch.ApiKey` |
| ES Cached Base64 | `.claude/elasticsearch-key.local.json` |
| GCP Service Account | `~/jacob_aaronson_service_account.json` |
| SSH (work repos) | `~/.ssh/id_work` |
| SSH (personal repos) | Default key |
| Atlassian Cloud ID | `559a76c5-7f47-4832-ab40-bd6462c90c6c` |
| Test env account ID | `e6593184d34648e981c8fd8c84084a2f` |
| Test env creds | `CLAUDE.local.md` (per-developer, not in source control) |

## Full Stack Startup Sequence

```bash
# 1. Docker services
cd ~/developer_bootstrap && docker compose up -d

# 2. Backend API
GOOGLE_APPLICATION_CREDENTIALS=~/jacob_aaronson_service_account.json \
ASPNETCORE_ENVIRONMENT=Development \
dotnet run --project ~/activecomply-api/src/activecomply.api.dashboard

# 3. Frontend
cd ~/dashboard-app && yarn start

# 4. Access at https://localhost:5173 (frontend proxies to API)
```

## VPN Requirement

All GKE clusters use `--internal-ip`. If kubectl or gcloud commands timeout → connect to VPN first.
