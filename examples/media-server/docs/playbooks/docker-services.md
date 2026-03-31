# Docker Services

## When
Adding, removing, or reconfiguring a service in the arr stack.

## Steps

1. Edit `/opt/arr-stack/docker-compose.yml`
2. Test: `docker compose config` (validates YAML)
3. Apply: `docker compose up -d <service>` (only restarts the changed service)
4. Verify: `docker compose ps` and check the service's web UI

## Adding a New Service
1. Add the service block to `docker-compose.yml`
2. Create config dir: `mkdir -p /opt/arr-stack/config/<service>`
3. Map volumes for config persistence and media access
4. Add to Homepage dashboard: edit `/opt/arr-stack/config/homepage/services.yaml`

## Key Commands
```bash
docker compose up -d           # Start all / apply changes
docker compose down            # Stop all (preserves volumes)
docker compose pull            # Update images
docker compose logs -f <svc>   # Follow logs
```

## Common Mistakes
- Forgetting volume mounts → config lost on container recreate
- Using `docker compose down -v` → deletes volumes and all config
- Not checking VPN is active before starting qBittorrent
