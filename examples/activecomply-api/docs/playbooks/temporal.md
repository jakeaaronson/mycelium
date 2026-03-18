# Playbook: Temporal Workflows

Temporal runs in Docker. All CLI commands go through the container.

## Common Commands

```bash
# List recent workflows
docker exec temporal temporal workflow list --limit 20

# Failed workflows
docker exec temporal temporal workflow list --query "ExecutionStatus='Failed'" --limit 10

# View specific workflow
docker exec temporal temporal workflow show -w <workflow-id>

# Follow workflow history
docker exec temporal temporal workflow show -w <workflow-id> --follow

# Worker status
docker exec temporal temporal task-queue describe --task-queue <queue-name>

# Schedules
docker exec temporal temporal schedule list
docker exec temporal temporal schedule describe --schedule-id <id>

# Health check
docker exec temporal temporal server health
```

## Tips

- Default namespace is `default` — add `--namespace <ns>` if different
- Add `--output json` for structured debugging output
- Worker services live in `activecomply.workflows.host`
