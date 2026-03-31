#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Mycelium Publish                                           ║
# ║                                                             ║
# ║  Publishes to GitHub and Forgejo while keeping private      ║
# ║  files local. Uses .publishignore to strip personal data.   ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Usage:
#   ./publish.sh                     # Interactive
#   ./publish.sh "v0.1: initial"     # Non-interactive
#   ./publish.sh --dry-run           # Show what would happen
#
# Local git tracks EVERYTHING (research, backups, sessions).
# Public repos only get the clean, publishable subset.
#
# Prerequisites:
#   git remote add github  git@github.com:USER/mycelium.git
#   git remote add forgejo git@forgejo.example.com:USER/mycelium.git

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

# ── Preflight ──
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo -e "${R}Not a git repo.${NC} Run: git init && git add -A && git commit -m 'initial'"
  exit 1
fi

BRANCH=$(git branch --show-current)

# ── Commit any uncommitted local changes first ──
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  UNCOMMITTED=$(git status --short | wc -l)
  echo -e "  ${Y}$UNCOMMITTED uncommitted changes.${NC}"
  if ! $DRY_RUN; then
    read -p "  Commit them now? [Y/n]: " yn
    case "$yn" in [Nn]*) echo "  Aborting."; exit 0 ;; esac
    git add -A
    git commit -m "wip: pre-publish checkpoint"
  fi
fi

# ── Count what's being published ──
TOTAL_COMMITS=$(git rev-list --count HEAD 2>/dev/null || echo 0)
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -n "$LAST_TAG" ]; then
  COMMITS_SINCE=$(git rev-list --count "$LAST_TAG"..HEAD)
else
  COMMITS_SINCE=$TOTAL_COMMITS
fi

# ── Read .publishignore ──
EXCLUDE_PATTERNS=()
if [ -f .publishignore ]; then
  while IFS= read -r line; do
    # Skip comments and blank lines
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    EXCLUDE_PATTERNS+=("$line")
  done < .publishignore
fi

# Count files that would be excluded
EXCLUDED_COUNT=0
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
  matches=$(git ls-files "$pattern" 2>/dev/null | wc -l)
  EXCLUDED_COUNT=$((EXCLUDED_COUNT + matches))
done

TRACKED=$(git ls-files | wc -l)
PUBLIC_COUNT=$((TRACKED - EXCLUDED_COUNT))

echo ""
echo -e "  ${B}Mycelium Publish${NC}"
echo ""
echo -e "  Branch: $BRANCH"
echo -e "  Total commits: $TOTAL_COMMITS"
echo -e "  Commits since last tag: ${B}$COMMITS_SINCE${NC}"
echo ""
echo -e "  ${B}Files:${NC}"
echo -e "    Local (tracked):     $TRACKED"
echo -e "    Public (published):  ${G}$PUBLIC_COUNT${NC}"
echo -e "    Private (stripped):  ${Y}$EXCLUDED_COUNT${NC}"
echo ""

if [ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]; then
  echo -e "  ${DIM}Stripped by .publishignore:${NC}"
  for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    count=$(git ls-files "$pattern" 2>/dev/null | wc -l)
    if [ "$count" -gt 0 ]; then
      echo -e "    ${DIM}$pattern ($count files)${NC}"
    fi
  done
  echo ""
fi

# ── Get message ──
if [ -z "$MESSAGE" ]; then
  echo "  Recent commits:"
  git log --oneline -10 | sed 's/^/    /'
  echo ""
  read -p "  Publish message (e.g. 'v0.1: initial release'): " MESSAGE
  if [ -z "$MESSAGE" ]; then
    echo "  No message. Aborting."
    exit 0
  fi
fi

# ── Build changelog entry from local commits ──
CHANGELOG_ENTRY="## $(date +%Y-%m-%d) . $MESSAGE

Changes:
$(git log --oneline ${LAST_TAG:+$LAST_TAG..}HEAD 2>/dev/null | sed 's/^[a-f0-9]* /- /' | head -30)
"

# ── Dry run ──
if $DRY_RUN; then
  echo -e "  ${B}DRY RUN${NC}"
  echo ""
  echo "  Would publish $PUBLIC_COUNT files (stripping $EXCLUDED_COUNT private files)"
  echo -e "  Tag: ${G}$MESSAGE${NC}"
  echo ""
  echo "  Would push to:"
  for remote in $(git remote); do
    url=$(git remote get-url "$remote" 2>/dev/null || echo "not configured")
    echo "    $remote -> $url"
  done
  if [ "$(git remote | wc -l)" -eq 0 ]; then
    echo "    (no remotes configured)"
  fi
  echo ""
  echo "  Changelog entry:"
  echo "$CHANGELOG_ENTRY" | sed 's/^/    /'
  echo ""
  echo "  Files that would be published:"
  git ls-files | while read f; do
    skip=false
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
      if [[ "$f" == $pattern* ]] || [[ "$f" == $pattern ]]; then
        skip=true
        break
      fi
    done
    if ! $skip; then echo "    $f"; fi
  done
  echo ""
  echo "  Run without --dry-run to execute."
  exit 0
fi

# ── Create temporary publish branch ──
PUBLISH_BRANCH="publish-staging-$$"
echo -e "  ${G}Creating clean publish branch...${NC}"

git checkout -b "$PUBLISH_BRANCH" --quiet

# Remove private files from the publish branch
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
  git rm -r --cached --quiet "$pattern" 2>/dev/null || true
done

# Commit the removal
git commit --quiet -m "strip private files for publish" --allow-empty

# Squash everything into one commit
git reset --soft $(git rev-list --max-parents=0 HEAD)
git commit --quiet -m "publish: $MESSAGE"

echo -e "  ${G}Squashed into clean publish commit.${NC}"

# ── Push to each remote ──
PUSH_SUCCESS=0
for remote in $(git remote); do
  url=$(git remote get-url "$remote" 2>/dev/null || echo "unknown")
  echo -e "  Pushing to ${B}$remote${NC} ($url)..."
  if git push "$remote" "$PUBLISH_BRANCH:main" --force 2>/dev/null; then
    echo -e "    ${G}OK${NC}"
    PUSH_SUCCESS=$((PUSH_SUCCESS + 1))
  else
    echo -e "    ${Y}Failed (remote may not exist yet)${NC}"
    echo -e "    Run: git remote add $remote <url>"
  fi
done

# ── Return to original branch ──
# Force checkout because stripped files are now untracked and would block the switch
git checkout "$BRANCH" --force --quiet
git branch -D "$PUBLISH_BRANCH" --quiet

# ── Tag the local commit ──
TAG_NAME=$(echo "$MESSAGE" | sed 's/[^a-zA-Z0-9._-]/-/g' | sed 's/--*/-/g' | tr '[:upper:]' '[:lower:]')
git tag -a "$TAG_NAME" -m "publish: $MESSAGE" 2>/dev/null || true

# ── Write changelog ──
if [ -f CHANGELOG.md ]; then
  EXISTING=$(cat CHANGELOG.md)
  echo "# Changelog" > CHANGELOG.md
  echo "" >> CHANGELOG.md
  echo "$CHANGELOG_ENTRY" >> CHANGELOG.md
  echo "$EXISTING" | tail -n +2 >> CHANGELOG.md
else
  echo "# Changelog" > CHANGELOG.md
  echo "" >> CHANGELOG.md
  echo "$CHANGELOG_ENTRY" >> CHANGELOG.md
fi
git add CHANGELOG.md
git commit --quiet -m "changelog: $MESSAGE"

echo ""
echo -e "  ${G}Published!${NC}"
echo ""
echo "  Tag: $TAG_NAME"
echo "  Pushed to: $PUSH_SUCCESS remote(s)"
echo "  Changelog written to CHANGELOG.md"
echo "  Local branch untouched (all private files still here)"
echo ""
