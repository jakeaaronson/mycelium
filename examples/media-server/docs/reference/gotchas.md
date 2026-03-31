# Gotchas

Non-obvious things that waste time if you don't know them.

- **qBittorrent temp password** resets on every container recreate. Even if you set a permanent password, it doesn't survive `docker compose down && up`.
- **qBittorrent IP ban** kicks in after ~5 failed logins. Fix: restart the container.
- **Path mapping** between containers is the #1 source of "download client unavailable" errors. qBit: `/downloads`. Radarr/Sonarr: `/data/torrents`. Mapped via Docker volumes.
- **exFAT storage drives** have no hardlinks, no symlinks, no Linux permissions. Cannot use for Timeshift, borg, or anything requiring POSIX.
- **Homepage API keys** must be real keys in `services.yaml`. The `{{HOMEPAGE_VAR_*}}` env var approach is broken in current Homepage versions.
- **Public torrent indexers** in Prowlarr go down frequently. Don't assume the stack is broken — test other indexers first.
- **NFS mount on workstation** is often not mounted. Verify: `mount | grep media-server`.
