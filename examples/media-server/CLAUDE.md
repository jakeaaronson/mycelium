# Media Server — Docker Arr Stack

Self-hosted media server running Docker compose on a dedicated Linux box.

## Stack
Docker compose (arr stack), Jellyfin, qBittorrent, Radarr, Sonarr, Prowlarr, Jellyseerr, Homepage dashboard

## Architecture
```
Jellyseerr → Radarr/Sonarr → qBittorrent (behind VPN) → /data/torrents → Jellyfin
```

## Hard Rules
- All services run in Docker — never install directly on the host
- qBittorrent must always be behind VPN — check before changing network config
- BigDrive is exFAT — no hardlinks, no symlinks, no POSIX permissions
- Don't restart all containers at once — services have startup dependencies

## Commands
```bash
# SSH to server
ssh user@media-server

# Service management
cd /opt/arr-stack && docker compose ps
cd /opt/arr-stack && docker compose restart <service>
cd /opt/arr-stack && docker compose logs --tail=50 <service>
```

## Before You Start

| Task | Read First |
|------|-----------|
| Check service status | Use `/media-server` skill |
| Add/configure a service | `docs/playbooks/docker-services.md` |
| Troubleshoot downloads | `docs/playbooks/download-pipeline.md` |
| Homepage dashboard changes | `docs/playbooks/homepage.md` |
| Port/network reference | `docs/reference/gotchas.md` |
