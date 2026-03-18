#!/bin/bash
# Rollback to a previous state of CLAUDE.md files and memory system.
#
# Usage:
#   ./rollback.sh              # Lists available backups, lets you choose
#   ./rollback.sh backup-2026-03-16   # Restores from specific backup
#   ./rollback.sh --dry-run    # Shows what would be restored without doing it

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

# Parse args
BACKUP_DIR=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) BACKUP_DIR="$arg" ;;
  esac
done

# List available backups
BACKUPS=()
while IFS= read -r -d '' dir; do
  BACKUPS+=("$(basename "$dir")")
done < <(find "$SCRIPT_DIR" -maxdepth 1 -type d -name "backup-*" -print0 | sort -z)

if [ ${#BACKUPS[@]} -eq 0 ]; then
  echo "No backups found in $SCRIPT_DIR"
  exit 1
fi

# Select backup
if [ -z "$BACKUP_DIR" ]; then
  echo "Available backups:"
  for i in "${!BACKUPS[@]}"; do
    backup="${BACKUPS[$i]}"
    file_count=$(find "$SCRIPT_DIR/$backup" -type f | wc -l)
    echo "  $((i+1))) $backup ($file_count files)"
  done
  echo ""
  read -p "Choose backup [1-${#BACKUPS[@]}]: " choice
  idx=$((choice - 1))
  if [ "$idx" -lt 0 ] || [ "$idx" -ge ${#BACKUPS[@]} ]; then
    echo "Invalid choice"
    exit 1
  fi
  BACKUP_DIR="${BACKUPS[$idx]}"
fi

BACKUP_PATH="$SCRIPT_DIR/$BACKUP_DIR"

if [ ! -d "$BACKUP_PATH" ]; then
  echo "ERROR: Backup not found: $BACKUP_PATH"
  exit 1
fi

echo "=== Rollback from $BACKUP_DIR ==="
if $DRY_RUN; then echo "(DRY RUN — no changes will be made)"; fi
echo ""

# Restore CLAUDE.md files
for backup_file in "$BACKUP_PATH"/claude-md-files/*_CLAUDE.md; do
  [ -f "$backup_file" ] || continue
  project=$(basename "$backup_file" | sed 's/_CLAUDE.md//')
  target="$HOME/$project/CLAUDE.md"
  if [ -f "$target" ] || [ -d "$HOME/$project" ]; then
    if $DRY_RUN; then
      echo "WOULD RESTORE: $target ($(wc -l < "$backup_file") lines)"
    else
      echo "Restoring: $target"
      cp "$backup_file" "$target"
    fi
  else
    echo "SKIP (project dir missing): $HOME/$project"
  fi
done

# Restore memory system
MEMORY_DIR="$HOME/.claude/projects/-home-jacob/memory"
if [ -d "$BACKUP_PATH/memory" ] && [ -d "$MEMORY_DIR" ]; then
  echo ""
  if $DRY_RUN; then
    echo "WOULD RESTORE memory system:"
    ls "$BACKUP_PATH/memory/" | sed 's/^/  /'
  else
    echo "Restoring memory system to: $MEMORY_DIR"
    cp "$BACKUP_PATH"/memory/* "$MEMORY_DIR/"
  fi
fi

echo ""
if $DRY_RUN; then
  echo "Dry run complete. Run without --dry-run to apply."
else
  echo "Rollback complete. Restart Claude Code to pick up changes."
fi
