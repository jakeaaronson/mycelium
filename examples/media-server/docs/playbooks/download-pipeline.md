# Download Pipeline

## When
Downloads aren't starting, stuck, or not being picked up by Jellyfin.

## Diagnosis Steps

1. **Check qBittorrent** (:8080) — is the download active?
   - If locked out: container temp password resets on recreate. Restart: `docker compose restart qbittorrent`
   - If IP banned: restart the container (resets ban list)

2. **Check Radarr/Sonarr** (:7878/:8989) → Activity tab
   - "Download client unavailable" = path mapping mismatch
   - qBit uses `/downloads`, Radarr expects `/data/torrents` — check Docker volume mounts

3. **Check Prowlarr** (:9696) → Indexers tab
   - If searches return nothing, indexers may be down — test manually

4. **Check Jellyfin** (:8096) → Library scan
   - New content won't appear until library scan runs
   - Manual: Dashboard → Libraries → Scan

## Pipeline Flow
```
User request (Jellyseerr :5055)
  → Radarr/Sonarr (HD-1080p profile)
    → qBittorrent (behind VPN)
      → /data/torrents
        → Jellyfin (auto-scan or manual)
```

## Common Mistakes
- Assuming downloads failed when qBit just needs a password reset
- Editing path mappings in Radarr UI instead of docker-compose.yml volumes
