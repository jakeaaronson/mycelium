# /media-server skill example

This example shows how procedural reference material becomes an executable skill.

## Before (verbose reference sheet — 52 lines)
A static document listing every port, every password, every service, the full pipeline diagram,
environment variables, storage details, and a "what still needs setup" section.
Problem: goes stale, read once then forgotten, most content discoverable via `docker ps`.

## After (skill — always fresh)
```yaml
name: media-server
description: Check media server status, manage Docker services, troubleshoot issues
allowed-tools: Bash, Read
```

The skill SSHes into the server and runs `docker ps`, `df -h`, VPN checks.
It returns *current* state, not a snapshot from when someone last updated a doc.

## What stays as a reference
Only the gotchas — things you can't derive from the running system:
- qBittorrent password behavior
- Path mapping between containers
- exFAT limitations
- Homepage API key workaround

These are ~7 lines instead of 52.
