#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║        Mycelium — Setup Wizard            ║
# ║                                                             ║
# ║  Interactive setup that walks you through:                  ║
# ║    1. What this is and how it works                         ║
# ║    2. Analyzing your current CLAUDE.md                      ║
# ║    3. Creating the pyramid directory structure              ║
# ║    4. Installing the feedback loop (hook + /reflect)        ║
# ║    5. Backfilling session history                           ║
# ║    6. Creating your first backup/restore point              ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Usage:
#   ./setup.sh                    # Full interactive wizard
#   ./setup.sh --feedback-only    # Only install hook + /reflect
#   ./setup.sh --uninstall        # Remove hook, skills, and cron

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

# ── Uninstall ──
if [[ "${1:-}" == "--uninstall" ]]; then
  echo "Uninstalling Mycelium..."
  rm -f "$CLAUDE_DIR/hooks/session-end-log.sh"
  rm -rf "$CLAUDE_DIR/skills/reflect"
  rm -rf "$CLAUDE_DIR/skills/status"
  crontab -l 2>/dev/null | grep -v "mycelium" | crontab - 2>/dev/null || true
  echo "Removed: hook, /reflect, /status, cron (if any)"
  echo "Kept: session-history.jsonl, backups, snapshots, docs"
  exit 0
fi

# ── Colors ──
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
P='\033[0;35m'
C='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# ── Helpers ──
hr() { echo -e "${DIM}$(printf '─%.0s' {1..60})${NC}"; }
ask() {
  local prompt="$1" default="${2:-}"
  if [ -n "$default" ]; then
    read -p "$(echo -e "  ${C}$prompt${NC} [$default]: ")" answer
    echo "${answer:-$default}"
  else
    read -p "$(echo -e "  ${C}$prompt${NC}: ")" answer
    echo "$answer"
  fi
}
confirm() {
  local prompt="$1"
  read -p "$(echo -e "  ${C}$prompt${NC} [Y/n]: ")" yn
  case "$yn" in [Nn]*) return 1 ;; *) return 0 ;; esac
}
pause() {
  read -p "$(echo -e "  ${DIM}Press Enter to continue...${NC}")"
}

# ═══════════════════════════════════════════════════════════════
# STEP 0: Welcome
# ═══════════════════════════════════════════════════════════════

clear
echo ""
echo -e "  ${BOLD}Mycelium${NC}"
echo -e "  ${DIM}Setup Wizard${NC}"
echo ""
hr
echo ""
echo -e "  This wizard will set up a ${BOLD}pyramid documentation system${NC}"
echo -e "  that makes your AI coding assistant work better by loading"
echo -e "  ${G}less, more relevant${NC} context instead of everything at once."
echo ""
echo -e "  ${BOLD}The problem:${NC} CLAUDE.md files grow over time. A 400-line"
echo -e "  CLAUDE.md means the model processes 400 lines on every"
echo -e "  conversation, even when only 30 are relevant."
echo ""
echo -e "  ${BOLD}The solution:${NC} A pyramid with 3 levels:"
echo ""
echo -e "    ${Y}Level 0${NC}  CLAUDE.md       ~50 lines, always loaded"
echo -e "    ${B}Level 1${NC}  Playbooks       loaded per task type"
echo -e "    ${P}Level 2${NC}  Reference       loaded when a playbook points to it"
echo ""
echo -e "  Plus a ${G}feedback loop${NC} that evolves the docs over time."
echo ""
hr
echo ""

if [[ "${1:-}" == "--feedback-only" ]]; then
  # Jump straight to feedback loop install
  SKIP_TO_FEEDBACK=true
else
  SKIP_TO_FEEDBACK=false
fi

# ═══════════════════════════════════════════════════════════════
# STEP 1: Discover projects
# ═══════════════════════════════════════════════════════════════

if [ "$SKIP_TO_FEEDBACK" = false ]; then

echo -e "  ${BOLD}Step 1: Find your projects${NC}"
echo ""

# Scan for CLAUDE.md files
CLAUDE_FILES=()
while IFS= read -r -d '' f; do
  CLAUDE_FILES+=("$f")
done < <(find "$HOME" -maxdepth 3 -name "CLAUDE.md" -not -path "*/.claude/*" -not -path "*/node_modules/*" -not -path "*/mycelium/*" -print0 2>/dev/null)

if [ ${#CLAUDE_FILES[@]} -eq 0 ]; then
  echo -e "  ${Y}No CLAUDE.md files found.${NC}"
  echo "  You can create one later using the templates in templates/"
  echo ""
else
  echo "  Found CLAUDE.md files:"
  echo ""
  for i in "${!CLAUDE_FILES[@]}"; do
    f="${CLAUDE_FILES[$i]}"
    dir=$(dirname "$f")
    project=$(basename "$dir")
    lines=$(wc -l < "$f")
    if [ "$lines" -gt 80 ]; then
      status="${R}${lines} lines — would benefit from pyramid${NC}"
    elif [ "$lines" -gt 50 ]; then
      status="${Y}${lines} lines — borderline${NC}"
    else
      status="${G}${lines} lines — already lean${NC}"
    fi
    echo -e "    $((i+1))) ${BOLD}$project${NC} — $status"
    echo -e "       ${DIM}$f${NC}"
  done
  echo ""

  # ═══════════════════════════════════════════════════════════════
  # STEP 2: Pick a project to set up
  # ═══════════════════════════════════════════════════════════════

  echo -e "  ${BOLD}Step 2: Choose a project to set up${NC}"
  echo ""

  if [ ${#CLAUDE_FILES[@]} -eq 1 ]; then
    CHOICE=1
    echo "  Only one project found — using it."
  else
    CHOICE=$(ask "Which project? [1-${#CLAUDE_FILES[@]}, or 's' to skip]" "1")
  fi

  if [[ "$CHOICE" != "s" ]]; then
    idx=$((CHOICE - 1))
    TARGET_FILE="${CLAUDE_FILES[$idx]}"
    TARGET_DIR=$(dirname "$TARGET_FILE")
    PROJECT_NAME=$(basename "$TARGET_DIR")
    LINES=$(wc -l < "$TARGET_FILE")

    echo ""
    hr
    echo ""
    echo -e "  ${BOLD}Step 3: Analyze $PROJECT_NAME${NC}"
    echo ""
    echo -e "  Current CLAUDE.md: ${BOLD}$LINES lines${NC}"
    echo ""

    if [ "$LINES" -le 50 ]; then
      echo -e "  ${G}Already under 50 lines — nice!${NC}"
      echo "  You may not need to restructure, but the playbook"
      echo "  system can still help organize task-specific knowledge."
    elif [ "$LINES" -le 100 ]; then
      echo -e "  ${Y}Moderate size.${NC} Probably has some reference material"
      echo "  that could be moved to playbooks."
    else
      echo -e "  ${R}Large file.${NC} Almost certainly has tutorial content,"
      echo "  reference tables, and edge-case instructions that"
      echo "  should move to Level 1 playbooks or Level 2 references."
    fi
    echo ""

    # Show section breakdown
    echo "  Sections found:"
    grep -n "^## " "$TARGET_FILE" 2>/dev/null | head -15 | while read line; do
      linenum=$(echo "$line" | cut -d: -f1)
      section=$(echo "$line" | cut -d: -f2- | sed 's/^## //')
      echo -e "    ${DIM}L${linenum}${NC}  $section"
    done
    echo ""

    # ═══════════════════════════════════════════════════════════════
    # STEP 4: Create directory structure
    # ═══════════════════════════════════════════════════════════════

    echo -e "  ${BOLD}Step 4: Create pyramid structure${NC}"
    echo ""
    echo "  This will create:"
    echo -e "    ${DIM}$TARGET_DIR/docs/playbooks/${NC}  (Level 1 — task guides)"
    echo -e "    ${DIM}$TARGET_DIR/docs/reference/${NC}  (Level 2 — lookup material)"
    echo ""

    if confirm "Create these directories?"; then
      mkdir -p "$TARGET_DIR/docs/playbooks" "$TARGET_DIR/docs/reference"
      echo -e "  ${G}Created.${NC}"
    else
      echo "  Skipped."
    fi
    echo ""

    # ═══════════════════════════════════════════════════════════════
    # STEP 5: Create backup
    # ═══════════════════════════════════════════════════════════════

    echo -e "  ${BOLD}Step 5: Create restore point${NC}"
    echo ""
    echo "  Before making any changes, we'll back up your current"
    echo "  CLAUDE.md so you can always go back."
    echo ""

    BACKUP_DIR="$SCRIPT_DIR/backup-$(date +%Y-%m-%d)"
    if [ -d "$BACKUP_DIR" ]; then
      echo -e "  ${Y}Backup already exists: $BACKUP_DIR${NC}"
    else
      if confirm "Create backup?"; then
        mkdir -p "$BACKUP_DIR/claude-md-files"
        cp "$TARGET_FILE" "$BACKUP_DIR/claude-md-files/${PROJECT_NAME}_CLAUDE.md"
        # Also backup memory if exists
        MEMORY_DIR="$CLAUDE_DIR/projects/-home-$(whoami)/memory"
        if [ -d "$MEMORY_DIR" ]; then
          mkdir -p "$BACKUP_DIR/memory"
          cp "$MEMORY_DIR"/* "$BACKUP_DIR/memory/" 2>/dev/null || true
        fi
        echo -e "  ${G}Backed up to: $BACKUP_DIR${NC}"
        echo "  Restore anytime with: ./rollback.sh"
      fi
    fi
    echo ""

    # ═══════════════════════════════════════════════════════════════
    # STEP 6: Copy templates
    # ═══════════════════════════════════════════════════════════════

    echo -e "  ${BOLD}Step 6: Seed with templates${NC}"
    echo ""
    echo "  Want me to copy starter templates into your project?"
    echo "  You'll customize them with your project's actual content."
    echo ""

    if confirm "Copy playbook + reference templates?"; then
      if [ ! -f "$TARGET_DIR/docs/playbooks/testing.md" ]; then
        cp "$SCRIPT_DIR/templates/playbook.md.template" "$TARGET_DIR/docs/playbooks/testing.md"
        sed -i "s/{Task Name}/Testing/" "$TARGET_DIR/docs/playbooks/testing.md"
        echo "  → docs/playbooks/testing.md"
      fi
      if [ ! -f "$TARGET_DIR/docs/reference/environment.md" ]; then
        cp "$SCRIPT_DIR/templates/reference.md.template" "$TARGET_DIR/docs/reference/environment.md"
        sed -i "s/{Topic}/Environment/" "$TARGET_DIR/docs/reference/environment.md"
        echo "  → docs/reference/environment.md"
      fi
      echo -e "  ${G}Templates copied. Edit them with your project's details.${NC}"
    else
      echo "  Skipped."
    fi
    echo ""

    # ═══════════════════════════════════════════════════════════════
    # STEP 6b: Generate for other tools
    # ═══════════════════════════════════════════════════════════════

    hr
    echo ""
    echo -e "  ${BOLD}Step 7: AI Tool Adapters${NC}"
    echo ""
    echo "  The pyramid works with any AI coding tool. Which do you use?"
    echo "  (Select all that apply, comma-separated, or press Enter to skip)"
    echo ""
    echo "    1) Claude Code     (CLAUDE.md)"
    echo "    2) Codex / OpenAI  (AGENTS.md)"
    echo "    3) Gemini CLI      (GEMINI.md)"
    echo "    4) Cursor          (.cursor/rules/)"
    echo "    5) Cline           (.clinerules/)"
    echo "    6) Windsurf        (.windsurfrules)"
    echo "    7) Goose           (.goosehints)"
    echo "    8) GitHub Copilot  (copilot-instructions.md)"
    echo ""
    TOOL_CHOICE=$(ask "Tools" "1")

    if [ -n "$TOOL_CHOICE" ]; then
      TOOL_MAP=("" "claude-code" "codex" "gemini" "cursor" "cline" "windsurf" "goose" "copilot")
      IFS=',' read -ra SELECTED <<< "$TOOL_CHOICE"
      TOOL_ARGS=""
      for sel in "${SELECTED[@]}"; do
        sel=$(echo "$sel" | tr -d ' ')
        if [[ "$sel" =~ ^[1-8]$ ]] && [ -n "${TOOL_MAP[$sel]}" ]; then
          TOOL_ARGS="${TOOL_MAP[$sel]}"
          echo -e "  Generating for ${G}${TOOL_MAP[$sel]}${NC}..."
          python3 "$SCRIPT_DIR/adapters/generate.py" "$TARGET_DIR" --tool "$TOOL_ARGS" 2>/dev/null || echo "  (skipped — run adapters/generate.py manually)"
        fi
      done
    fi

    hr
    echo ""
    echo -e "  ${BOLD}Project structure ready!${NC}"
    echo ""
    echo "  Next steps for $PROJECT_NAME:"
    echo "    1. Read your current CLAUDE.md (or generated instruction file)"
    echo "    2. Move task-specific content to docs/playbooks/"
    echo "    3. Move lookup material to docs/reference/"
    echo "    4. Add a routing table to your L0 file"
    echo "    5. Trim L0 to ~50 lines"
    echo ""
    echo "  See examples/ in this repo for reference."
    echo ""
    pause
  fi

fi  # end if CLAUDE_FILES found

fi  # end SKIP_TO_FEEDBACK

# ═══════════════════════════════════════════════════════════════
# STEP 7: Install feedback loop
# ═══════════════════════════════════════════════════════════════

hr
echo ""
echo -e "  ${BOLD}Feedback Loop Setup${NC}"
echo ""
echo -e "  The feedback loop has two pieces:"
echo ""
echo -e "    ${G}SessionEnd hook${NC}  — Runs after every Claude Code session."
echo -e "                      Detects signals (corrections, frustrations,"
echo -e "                      re-explanations) and flags sessions for review."
echo ""
echo -e "    ${G}/reflect${NC}         — Command you run when you want to improve"
echo -e "                      your docs. Reads flagged sessions, understands"
echo -e "                      what went wrong, edits the docs."
echo -e "                      Three levels: quick fix, deep analysis,"
echo -e "                      or architectural rethink."
echo ""

if confirm "Install the feedback loop?"; then
  echo ""

  # Hook
  echo -e "  ${G}[1/3]${NC} Installing SessionEnd hook..."
  mkdir -p "$CLAUDE_DIR/hooks"
  cp "$SCRIPT_DIR/feedback-loop/session-end-log.sh" "$CLAUDE_DIR/hooks/session-end-log.sh"
  chmod +x "$CLAUDE_DIR/hooks/session-end-log.sh"
  echo "    → $CLAUDE_DIR/hooks/session-end-log.sh"

  SETTINGS="$CLAUDE_DIR/settings.json"
  if [ -f "$SETTINGS" ] && grep -q "SessionEnd" "$SETTINGS" 2>/dev/null; then
    echo "    → Hook already in settings.json"
  else
    echo ""
    echo -e "  ${Y}ACTION NEEDED:${NC} Add this to $SETTINGS inside the top-level object:"
    echo ""
    echo '    "hooks": { "SessionEnd": [{ "hooks": [{'
    echo '      "type": "command",'
    echo "      \"command\": \"$CLAUDE_DIR/hooks/session-end-log.sh\","
    echo '      "timeout": 15 }]}]}'
    echo ""
    pause
  fi

  # /reflect + /status
  echo -e "  ${G}[2/3]${NC} Installing /reflect and /status commands..."
  mkdir -p "$CLAUDE_DIR/skills/reflect"
  cp "$SCRIPT_DIR/feedback-loop/reflect-skill/SKILL.md" "$CLAUDE_DIR/skills/reflect/SKILL.md"
  echo "    → /reflect (3 levels + undo + dry-run)"
  if [ -f "$CLAUDE_DIR/skills/status/SKILL.md" ]; then
    echo "    → /status already installed"
  fi

  # Backfill history
  echo -e "  ${G}[3/3]${NC} Session history..."
  HISTORY="$CLAUDE_DIR/session-history.jsonl"
  if [ -f "$HISTORY" ] && [ -s "$HISTORY" ]; then
    TOTAL=$(wc -l < "$HISTORY")
    FLAGGED=$(grep -c '"needs_review":true' "$HISTORY" 2>/dev/null || echo 0)
    echo "    → $TOTAL sessions logged, $FLAGGED flagged"
  elif [ -f "$SCRIPT_DIR/feedback-loop/backfill-history.py" ]; then
    echo "    Backfilling from existing sessions..."
    python3 "$SCRIPT_DIR/feedback-loop/backfill-history.py"
  else
    echo "    → No history yet. Starts logging from your next session."
  fi

  echo -e "\n  ${G}Feedback loop installed.${NC}"
else
  echo "  Skipped."
fi

# ═══════════════════════════════════════════════════════════════
# STEP 8: Summary
# ═══════════════════════════════════════════════════════════════

echo ""
hr
echo ""
echo -e "  ${BOLD}Setup Complete${NC}"
echo ""
echo -e "  ${G}What's ready:${NC}"
echo "    • Pyramid directory structure"
echo "    • Backup / restore point"
echo "    • SessionEnd hook (auto-logs every session)"
echo "    • /reflect command (3 levels of doc improvement)"
echo "    • /status command (quick health check)"
echo ""
echo -e "  ${G}Your daily workflow:${NC}"
echo "    1. Use Claude Code normally"
echo "    2. After important sessions: /reflect"
echo "    3. Weekly deep dive: /reflect 2"
echo "    4. Check health anytime: /status"
echo ""
echo -e "  ${G}Useful commands:${NC}"
echo "    /reflect          Quick doc fixes from recent sessions"
echo "    /reflect 2        Deep analysis + restructure"
echo "    /reflect 3        Rethink the framework (contributors)"
echo "    /reflect undo     Restore from last snapshot"
echo "    /status           Health check"
echo "    ./rollback.sh     Restore original CLAUDE.md files"
echo ""
echo -e "  ${G}Viewer:${NC}"
echo "    python3 build-viewer.py    # Rebuild the HTML doc browser"
echo "    open viewer.html           # Browse your pyramid"
echo ""
echo -e "  ${DIM}Documentation: README.md${NC}"
echo -e "  ${DIM}Examples: examples/activecomply-api/ and examples/thezeitgeistexperiment/${NC}"
echo -e "  ${DIM}License: Anti-Capitalist Software License v1.4${NC}"
echo ""
