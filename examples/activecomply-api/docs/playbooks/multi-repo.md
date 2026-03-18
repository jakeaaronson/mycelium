# Playbook: Multi-Repo Operations

## Repository Locations

| Repo | Path | Stack | Default Branch |
|------|------|-------|---------------|
| activecomply-api | `~/activecomply-api` | .NET 8 / C# | `development` |
| dashboard-app | `~/dashboard-app` | React / JS / EUI | `development` |
| survey-app | `~/survey-app` | React / Vite / Firebase | `development` |
| dev-agents | `~/dev-agents` | Multi-project orchestration | `development` |

## Cross-Repo Changes

When a change spans backend + frontend:
1. Make backend changes in `~/activecomply-api`
2. Make frontend changes in `~/dashboard-app`
3. Create separate PRs for each repo
4. Note the dependency in both PR descriptions

## Local Dev Stack

Full stack requires (in order):
1. Docker services: `cd ~/developer_bootstrap && docker compose up -d` (ES, Redis, RabbitMQ, Temporal)
2. Backend: `GOOGLE_APPLICATION_CREDENTIALS=~/jacob_aaronson_service_account.json ASPNETCORE_ENVIRONMENT=Development dotnet run --project ~/activecomply-api/src/activecomply.api.dashboard`
3. Frontend: `cd ~/dashboard-app && yarn start`

Ports: ES 9200, Kibana 5601, RabbitMQ 15672, Redis 6379, Temporal 7233, Dashboard API 5001, Frontend 5173

## SSH Key

Work repos use `~/.ssh/id_work`. Clone with:
```bash
GIT_SSH_COMMAND="ssh -i ~/.ssh/id_work" git clone git@github.com:activecomply/{repo}.git
```
