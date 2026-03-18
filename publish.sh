#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Mycelium Publish Script                                    ║
# ║                                                             ║
# ║  Squashes local commits into one clean commit, pushes to    ║
# ║  GitHub and Forgejo, and generates a changelog entry.       ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Usage:
#   ./publish.sh                  # Interactive: asks for commit message
#   ./publish.sh "v0.1: initial"  # Non-interactive
#   ./publish.sh --dry-run        # Show what would happen
#
# Prerequisites:
#   git remote add github  git@github.com:USERNAME/mycelium.git
#   git remote add forgejo git@forgejo.example.com:USERNAME/mycelium.git

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

G='\033[0;32m'
Y='\033[1;33m'
R='\033[0;31m'
DIM='\033[2m'
B='\033[1m'
NC='\033[0m'

DRY_RUN=false
MESSAGE=""

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) MESSAGE="$arg" ;;
  esac
done

# ── Preflight checks ──
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo -e "${R}Not a git repository.${NC} Run: git init && git add -A && git commit -m 'initial'"
  exit 1
fi

BRANCH=$(git branch --show-current)
if [ "$BRANCH" != "main" ] && [ "$BRANCH" != "master" ]; then
  echo -e "${Y}Warning: on branch '$BRANCH', not main.${NC}"
fi

# ── Show what's pending ──
LAST_PUBLISH=$(git log --oneline --grep="publish:" --max-count=1 --format="%h %s" 2>/dev/null || echo "none")
COMMITS_SINCE=$(git log --oneline $(git log --grep="publish:" --max-count=1 --format="%h" 2>/dev/null || echo "HEAD~100")..HEAD 2>/dev/null | wc -l)
FILES_CHANGED=$(git diff --stat $(git log --grep="publish:" --max-count=1 --format="%h" 2>/dev/null || echo "HEAD~100")..HEAD 2>/dev/null | tail -1 || echo "unknown")

echo ""
echo -e "  ${B}Mycelium Publish${NC}"
echo ""
echo -e "  Last publish: ${DIM}$LAST_PUBLISH${NC}"
echo -e "  Commits since: ${B}$COMMITS_SINCE${NC}"
echo -e "  Changes: ${DIM}$FILES_CHANGED${NC}"
echo ""

# ── Check for uncommitted changes ──
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  UNCOMMITTED=$(git status --short | wc -l)
  echo -e "  ${Y}$UNCOMMITTED uncommitted changes.${NC}"
  if $DRY_RUN; then
    echo "  (dry-run: would commit these first)"
  else
    read -p "  Commit them now? [Y/n]: " yn
    case "$yn" in [Nn]*) echo "  Aborting."; exit 0 ;; esac
    git add -A
    git commit -m "wip: uncommitted changes before publish"
    echo ""
  fi
fi

# ── Get commit message ──
if [ -z "$MESSAGE" ]; then
  echo "  Recent commits:"
  git log --oneline -10 | sed 's/^/    /'
  echo ""
  read -p "  Publish message (e.g. 'v0.1: initial release'): " MESSAGE
  if [ -z "$MESSAGE" ]; then
    echo "  No message, aborting."
    exit 0
  fi
fi

# ── Generate changelog entry ──
CHANGELOG_ENTRY="## $(date +%Y-%m-%d) . $MESSAGE

$(git log --oneline $(git log --grep="publish:" --max-count=1 --format="%h" 2>/dev/null || echo "--root")..HEAD 2>/dev/null | sed 's/^[a-f0-9]* /- /')

Files changed:
$FILES_CHANGED
"

if $DRY_RUN; then
  echo -e "  ${B}DRY RUN${NC}"
  echo ""
  echo "  Would squash $COMMITS_SINCE commits into:"
  echo -e "    ${G}publish: $MESSAGE${NC}"
  echo ""
  echo "  Would push to:"
  for remote in $(git remote); do
    url=$(git remote get-url "$remote" 2>/dev/null || echo "unknown")
    echo "    $remote -> $url"
  done
  echo ""
  echo "  Changelog entry:"
  echo "$CHANGELOG_ENTRY" | sed 's/^/    /'
  echo ""
  echo "  Run without --dry-run to execute."
  exit 0
fi

# ── Squash commits ──
echo -e "  ${G}Squashing $COMMITS_SINCE commits...${NC}"

# Find the last publish commit, or the root
LAST_HASH=$(git log --grep="publish:" --max-count=1 --format="%h" 2>/dev/null || echo "")

if [ -n "$LAST_HASH" ]; then
  # Soft reset to the last publish point, then recommit everything
  git reset --soft "$LAST_HASH"
else
  # No previous publish. Squash everything into one commit.
  # Reset to root but keep all changes staged
  FIRST=$(git rev-list --max-parents=0 HEAD)
  git reset --soft "$FIRST"
fi

git add -A
git commit -m "$(cat <<EOF
publish: $MESSAGE

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"

echo -e "  ${G}Squashed into one clean commit.${NC}"

# ── Write changelog ──
if [ -f CHANGELOG.md ]; then
  # Prepend new entry after the header
  HEADER=$(head -2 CHANGELOG.md)
  BODY=$(tail -n +3 CHANGELOG.md)
  echo "$HEADER" > CHANGELOG.md
  echo "" >> CHANGELOG.md
  echo "$CHANGELOG_ENTRY" >> CHANGELOG.md
  echo "$BODY" >> CHANGELOG.md
else
  echo "# Changelog" > CHANGELOG.md
  echo "" >> CHANGELOG.md
  echo "$CHANGELOG_ENTRY" >> CHANGELOG.md
fi

git add CHANGELOG.md
git commit --amend --no-edit

echo -e "  ${G}Changelog updated.${NC}"

# ── Push to remotes ──
for remote in $(git remote); do
  url=$(git remote get-url "$remote" 2>/dev/null || echo "unknown")
  echo -e "  Pushing to ${B}$remote${NC} ($url)..."
  if git push "$remote" "$BRANCH" --force-with-lease 2>/dev/null; then
    echo -e "    ${G}OK${NC}"
  else
    echo -e "    ${Y}Failed. You may need to set up the remote:${NC}"
    echo "    git remote add $remote <url>"
  fi
done

echo ""
echo -e "  ${G}Published!${NC}"
echo ""
echo "  Changelog entry written to CHANGELOG.md"
echo "  To generate a blog post from this, copy the changelog entry."
echo ""
