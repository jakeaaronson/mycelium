#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Mycelium Setup Wizard                                      ║
# ║                                                             ║
# ║  Self-improving memory and documentation system for AI      ║
# ║  coding agents. Hierarchical memory for non-hierarchical    ║
# ║  organizations.                                             ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Usage:
#   ./setup.sh                    # Full interactive wizard
#   ./setup.sh --feedback-only    # Only install hook + /reflect
#   ./setup.sh --uninstall        # Remove everything

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

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
hr() { echo -e "${DIM}$(printf '~%.0s' {1..60})${NC}"; }
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

# ── Uninstall ──
if [[ "${1:-}" == "--uninstall" ]]; then
  echo ""
  echo -e "  ${BOLD}Mycelium Uninstall${NC}"
  echo ""

  # Remove feedback loop
  echo -e "  ${G}[1/2]${NC} Removing feedback loop..."
  rm -f "$CLAUDE_DIR/hooks/session-end-log.sh"
  rm -rf "$CLAUDE_DIR/skills/reflect"
  rm -rf "$CLAUDE_DIR/skills/status"
  echo "    Removed: hook, /reflect, /status"

  # Find and restore project backups
  echo -e "  ${G}[2/2]${NC} Checking for project backups..."
  RESTORED=0
  while IFS= read -r -d '' backup_dir; do
    project_dir=$(dirname "$backup_dir")
    project=$(basename "$project_dir")
    # Find the backed-up instruction file
    for f in "$backup_dir"/*; do
      [ -f "$f" ] || continue
      fname=$(basename "$f")
      target="$project_dir/$fname"
      echo -e "    Found backup: ${BOLD}$project${NC}/$fname"
      echo -n "    "
      read -p "$(echo -e "${C}Restore original $fname? [Y/n]:${NC} ")" yn
      case "$yn" in
        [Nn]*) echo "    Skipped." ;;
        *)
          cp "$f" "$target"
          echo -e "    ${G}Restored.${NC}"
          RESTORED=$((RESTORED + 1))
          ;;
      esac
    done
  done < <(find "$HOME" -maxdepth 4 -type d -name ".pyramid-backup" -print0 2>/dev/null)

  if [ "$RESTORED" -eq 0 ]; then
    echo "    No project backups found (or all skipped)."
    echo "    No backups to restore."
  fi

  # Ask about removing pyramid directories
  echo ""
  echo -n "  "
  read -p "$(echo -e "${C}Also remove docs/playbooks/ and docs/reference/ from projects? [y/N]:${NC} ")" yn
  case "$yn" in
    [Yy]*)
      while IFS= read -r -d '' pb_dir; do
        project_dir=$(dirname "$(dirname "$pb_dir")")
        project=$(basename "$project_dir")
        rm -rf "$project_dir/docs/playbooks" "$project_dir/docs/reference"
        # Remove docs/ if empty
        rmdir "$project_dir/docs" 2>/dev/null || true
        echo "    Removed pyramid dirs from $project"
      done < <(find "$HOME" -maxdepth 5 -type d -name "playbooks" -path "*/docs/playbooks" -print0 2>/dev/null)
      ;;
    *) echo "    Kept project directories." ;;
  esac

  echo ""
  echo -e "  ${G}Uninstall complete.${NC}"
  echo "  Kept: session-history.jsonl, ~/mycelium/ repo"
  echo ""
  exit 0
fi

SKIP_TO_FEEDBACK=false
if [[ "${1:-}" == "--feedback-only" ]]; then
  SKIP_TO_FEEDBACK=true
fi

# ═══════════════════════════════════════════════════════════════
# WELCOME
# ═══════════════════════════════════════════════════════════════

clear
echo ""
echo -e "  ${BOLD}Mycelium${NC}"
echo -e "  ${DIM}Self-improving memory for AI coding agents${NC}"
echo ""
hr
echo ""
echo -e "  Your AI assistant forgets everything between conversations."
echo -e "  Mycelium fixes that by loading ${G}only what's relevant${NC} and"
echo -e "  getting smarter every session."
echo ""
echo -e "  This wizard will:"
echo -e "    1. Ask which AI tool(s) you use"
echo -e "    2. Find your projects"
echo -e "    3. Analyze and split bloated instruction files"
echo -e "    4. Install the feedback loop"
echo ""
echo -e "  Everything is reversible. Backups are created before any changes."
echo ""
hr
echo ""

if [ "$SKIP_TO_FEEDBACK" = false ]; then

# ═══════════════════════════════════════════════════════════════
# STEP 1: Which AI tool(s)?
# ═══════════════════════════════════════════════════════════════

echo -e "  ${BOLD}Step 1: Which AI tool(s) do you use?${NC}"
echo ""
echo "    1) Claude Code     (CLAUDE.md)"
echo "    2) Codex / OpenAI  (AGENTS.md)"
echo "    3) Gemini CLI      (GEMINI.md)"
echo "    4) Cursor          (.cursor/rules/)"
echo "    5) Cline           (.clinerules/)"
echo "    6) Windsurf        (.windsurfrules)"
echo "    7) Goose           (.goosehints)"
echo "    8) GitHub Copilot  (copilot-instructions.md)"
echo "    9) All / not sure  (scan for everything)"
echo ""
TOOL_CHOICE=$(ask "Select tools, comma-separated" "9")

# Build list of filenames to scan for
SCAN_FILES=()
IFS=',' read -ra SELECTIONS <<< "$TOOL_CHOICE"
for sel in "${SELECTIONS[@]}"; do
  sel=$(echo "$sel" | tr -d ' ')
  case "$sel" in
    1) SCAN_FILES+=("CLAUDE.md") ;;
    2) SCAN_FILES+=("AGENTS.md") ;;
    3) SCAN_FILES+=("GEMINI.md" "AGENT.md") ;;
    4) SCAN_FILES+=(".cursorrules") ;;
    5) SCAN_FILES+=(".clinerules") ;;
    6) SCAN_FILES+=(".windsurfrules") ;;
    7) SCAN_FILES+=(".goosehints") ;;
    8) SCAN_FILES+=("copilot-instructions.md") ;;
    9|*) SCAN_FILES=("CLAUDE.md" "AGENTS.md" "GEMINI.md" ".cursorrules" ".goosehints" ".windsurfrules" ".clinerules" "copilot-instructions.md") ;;
  esac
done

# Deduplicate
SCAN_FILES=($(printf '%s\n' "${SCAN_FILES[@]}" | sort -u))

echo ""

# ═══════════════════════════════════════════════════════════════
# STEP 2: Find projects (multiple signals)
# ═══════════════════════════════════════════════════════════════

echo -e "  ${BOLD}Step 2: Finding your projects...${NC}"
echo ""

# Use associative-style arrays (parallel arrays for bash 3 compat)
FOUND_PROJECTS=()
FOUND_FILES=()
FOUND_LINES=()
FOUND_SESSIONS=()
FOUND_SOURCE=()

# Helper: add project if not already found
add_project() {
  local dir="$1" file="$2" lines="$3" sessions="$4" source="$5"
  # Skip mycelium, node_modules, .git, .claude internals, backups
  case "$dir" in
    *mycelium*|*node_modules*|*/.git/*|*/.git|*/.claude/*|*.pyramid-backup*|*/backup-*) return ;;
  esac
  # Check if already added
  for existing in "${FOUND_PROJECTS[@]}"; do
    [ "$existing" = "$dir" ] && return
  done
  FOUND_PROJECTS+=("$dir")
  FOUND_FILES+=("$file")
  FOUND_LINES+=("$lines")
  FOUND_SESSIONS+=("$sessions")
  FOUND_SOURCE+=("$source")
}

# Signal 1: Existing instruction files
echo -e "  ${DIM}Scanning for instruction files...${NC}"
for scan_name in "${SCAN_FILES[@]}"; do
  while IFS= read -r -d '' f; do
    dir=$(dirname "$f")
    fname=$(basename "$f")
    lines=$(wc -l < "$f" 2>/dev/null || echo 0)
    add_project "$dir" "$fname" "$lines" "?" "instruction file"
  done < <(find "$HOME" -maxdepth 4 -name "$scan_name" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/mycelium/*" -not -path "*/.pyramid-backup/*" -not -path "*/backup-*/*" -print0 2>/dev/null)
done

# Signal 2: Directories with Claude Code session history
echo -e "  ${DIM}Scanning session history...${NC}"
if [ -d "$CLAUDE_DIR/projects" ]; then
  for proj_dir in "$CLAUDE_DIR/projects/"*/; do
    [ -d "$proj_dir" ] || continue
    # Decode the project path from the directory name
    proj_name=$(basename "$proj_dir")
    # Convert -home-jacob-projectname to /home/jacob/projectname
    decoded_path=$(echo "$proj_name" | sed 's|^-|/|; s|-|/|g')

    # Only add if the directory actually exists
    if [ -d "$decoded_path" ]; then
      session_count=$(find "$proj_dir" -maxdepth 1 -name "*.jsonl" 2>/dev/null | wc -l)
      if [ "$session_count" -gt 0 ]; then
        # Check if it already has an instruction file
        existing_file="none"
        existing_lines=0
        for name in "${SCAN_FILES[@]}"; do
          if [ -f "$decoded_path/$name" ]; then
            existing_file="$name"
            existing_lines=$(wc -l < "$decoded_path/$name" 2>/dev/null || echo 0)
            break
          fi
        done
        add_project "$decoded_path" "$existing_file" "$existing_lines" "$session_count" "session history"
      fi
    fi
  done
fi

# Signal 3: Git repos in home directory (shallow scan)
echo -e "  ${DIM}Scanning for git repos...${NC}"
for gitdir in "$HOME"/*/.git; do
  [ -d "$gitdir" ] || continue
  dir=$(dirname "$gitdir")
  existing_file="none"
  existing_lines=0
  for name in "${SCAN_FILES[@]}"; do
    if [ -f "$dir/$name" ]; then
      existing_file="$name"
      existing_lines=$(wc -l < "$dir/$name" 2>/dev/null || echo 0)
      break
    fi
  done
  add_project "$dir" "$existing_file" "$existing_lines" "?" "git repo"
done

# Fill in session counts for projects found by other signals
for i in "${!FOUND_PROJECTS[@]}"; do
  if [ "${FOUND_SESSIONS[$i]}" = "?" ]; then
    dir="${FOUND_PROJECTS[$i]}"
    proj_encoded=$(echo "$dir" | sed 's|/|-|g; s|^-||')
    if [ -d "$CLAUDE_DIR/projects/-$proj_encoded" ]; then
      count=$(find "$CLAUDE_DIR/projects/-$proj_encoded" -maxdepth 1 -name "*.jsonl" 2>/dev/null | wc -l)
      FOUND_SESSIONS[$i]="$count"
    else
      FOUND_SESSIONS[$i]="0"
    fi
  fi
done

echo ""

if [ ${#FOUND_PROJECTS[@]} -eq 0 ]; then
  echo -e "  ${Y}No projects found.${NC}"
  echo ""
  echo "  You can add a project manually:"
  echo "    mkdir -p ~/my-project/docs/playbooks ~/my-project/docs/reference"
  echo ""
  pause
else
  echo "  Found ${#FOUND_PROJECTS[@]} project(s):"
  echo ""
  for i in "${!FOUND_PROJECTS[@]}"; do
    dir="${FOUND_PROJECTS[$i]}"
    file="${FOUND_FILES[$i]}"
    lines="${FOUND_LINES[$i]}"
    sessions="${FOUND_SESSIONS[$i]}"
    project=$(basename "$dir")

    # Build status string
    if [ "$file" = "none" ]; then
      file_status="${DIM}no instruction file${NC}"
    elif [ "$lines" -gt 80 ]; then
      file_status="${R}${file} ${lines}L . needs work${NC}"
    elif [ "$lines" -gt 50 ]; then
      file_status="${Y}${file} ${lines}L . borderline${NC}"
    else
      file_status="${G}${file} ${lines}L${NC}"
    fi

    if [ "$sessions" -gt 10 ]; then
      session_status="${G}${sessions} sessions${NC}"
    elif [ "$sessions" -gt 0 ]; then
      session_status="${Y}${sessions} sessions${NC}"
    else
      session_status="${DIM}no history${NC}"
    fi

    echo -e "    $((i+1))) ${BOLD}$project${NC}"
    echo -e "       $file_status . $session_status"
    echo -e "       ${DIM}$dir${NC}"
  done

  # Option to add more
  echo ""
  echo -e "  ${DIM}To add a project not listed, enter its path at the prompt.${NC}"
  echo ""

  # ═══════════════════════════════════════════════════════════════
  # STEP 3: Pick projects
  # ═══════════════════════════════════════════════════════════════

  echo -e "  ${BOLD}Step 3: Which projects to set up?${NC}"
  echo ""
  echo "  Enter numbers (comma-separated), 'a' for all, 's' to skip,"
  echo "  or a path to add a project not listed (e.g. ~/my-project)"
  echo ""
  PROJECT_CHOICE=$(ask "Projects" "a")

  SELECTED_INDICES=()
  if [[ "$PROJECT_CHOICE" == "a" ]]; then
    for i in "${!FOUND_PROJECTS[@]}"; do SELECTED_INDICES+=("$i"); done
  elif [[ "$PROJECT_CHOICE" == "s" ]]; then
    : # skip
  elif [[ "$PROJECT_CHOICE" == /* ]] || [[ "$PROJECT_CHOICE" == ~* ]]; then
    # User entered a path. Expand ~ and add it.
    CUSTOM_PATH=$(eval echo "$PROJECT_CHOICE")
    if [ -d "$CUSTOM_PATH" ]; then
      add_project "$CUSTOM_PATH" "none" "0" "0" "manual"
      SELECTED_INDICES+=("$((${#FOUND_PROJECTS[@]} - 1))")
      echo -e "  ${G}Added: $CUSTOM_PATH${NC}"
    else
      echo -e "  ${R}Directory not found: $CUSTOM_PATH${NC}"
    fi
  else
    IFS=',' read -ra PICKS <<< "$PROJECT_CHOICE"
    for pick in "${PICKS[@]}"; do
      pick=$(echo "$pick" | tr -d ' ')
      if [[ "$pick" =~ ^[0-9]+$ ]]; then
        idx=$((pick - 1))
        if [ "$idx" -ge 0 ] && [ "$idx" -lt ${#FOUND_PROJECTS[@]} ]; then
          SELECTED_INDICES+=("$idx")
        fi
      fi
    done
  fi

  # ═══════════════════════════════════════════════════════════════
  # STEP 4: Prepare each project
  # ═══════════════════════════════════════════════════════════════

  SETUP_PROJECTS=()

  for idx in "${SELECTED_INDICES[@]}"; do
    dir="${FOUND_PROJECTS[$idx]}"
    file="${FOUND_FILES[$idx]}"
    lines="${FOUND_LINES[$idx]}"
    project=$(basename "$dir")

    echo ""
    hr
    echo ""
    echo -e "  ${BOLD}Setting up: $project${NC}"
    if [ "$file" != "none" ]; then
      echo -e "  ${DIM}$dir/$file ($lines lines)${NC}"
    else
      echo -e "  ${DIM}$dir (no instruction file yet)${NC}"
    fi
    echo ""

    # Backup original if it exists
    if [ "$file" != "none" ] && [ -f "$dir/$file" ]; then
      BACKUP_DIR="$dir/.pyramid-backup"
      if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        cp "$dir/$file" "$BACKUP_DIR/$file"
        echo -e "  ${G}Backed up:${NC} $file -> .pyramid-backup/$file"
      else
        echo -e "  ${DIM}Backup already exists at .pyramid-backup/${NC}"
      fi
    fi

    # Create instruction file if it doesn't exist
    if [ "$file" = "none" ]; then
      # Determine filename from tool choice
      TOOL_FILE="CLAUDE.md"
      case "${SELECTIONS[0]:-9}" in
        1) TOOL_FILE="CLAUDE.md" ;;
        2) TOOL_FILE="AGENTS.md" ;;
        3) TOOL_FILE="GEMINI.md" ;;
        7) TOOL_FILE=".goosehints" ;;
        *) TOOL_FILE="CLAUDE.md" ;;
      esac
      echo -e "  Creating ${G}$TOOL_FILE${NC} with minimal template..."
      cat > "$dir/$TOOL_FILE" << TEMPLATE
# $(basename "$dir")

## Before You Start

| Task | Read First |
|------|-----------|
| (playbooks will be created by /reflect 2) | docs/playbooks/ |
TEMPLATE
      file="$TOOL_FILE"
      echo -e "  ${G}Created:${NC} $file"
    fi

    # Create pyramid structure
    mkdir -p "$dir/docs/playbooks" "$dir/docs/reference"
    echo -e "  ${G}Created:${NC} docs/playbooks/ and docs/reference/"

    # Count existing session history for this project
    HISTORY="$CLAUDE_DIR/session-history.jsonl"
    SESSION_COUNT=0
    if [ -f "$HISTORY" ]; then
      SESSION_COUNT=$(grep -c "\"$project\"" "$HISTORY" 2>/dev/null || echo 0)
    fi
    # Also check raw session files
    RAW_SESSIONS=$(find "$CLAUDE_DIR/projects/" -maxdepth 2 -name "*.jsonl" -path "*${project}*" 2>/dev/null | wc -l)
    TOTAL_SESSIONS=$((SESSION_COUNT > RAW_SESSIONS ? SESSION_COUNT : RAW_SESSIONS))

    if [ "$TOTAL_SESSIONS" -gt 5 ]; then
      echo ""
      echo -e "  ${G}Found ~$TOTAL_SESSIONS sessions of conversation history.${NC}"
      echo -e "  That's enough data to build great playbooks."
    elif [ "$TOTAL_SESSIONS" -gt 0 ]; then
      echo ""
      echo -e "  ${Y}Found ~$TOTAL_SESSIONS sessions.${NC} Some data to work with."
    else
      echo ""
      echo -e "  ${DIM}No conversation history found yet.${NC}"
    fi

    if [ "$lines" -le 50 ]; then
      echo -e "  ${G}$file is already lean ($lines lines). Good starting point.${NC}"
    else
      echo -e "  ${Y}$file is $lines lines. /reflect 2 will analyze your history${NC}"
      echo -e "  ${Y}and build focused playbooks from your actual usage patterns.${NC}"
    fi

    SETUP_PROJECTS+=("$dir")
  done

  # ═══════════════════════════════════════════════════════════════
  # Summary of what /reflect 2 will do
  # ═══════════════════════════════════════════════════════════════

  if [ ${#SETUP_PROJECTS[@]} -gt 0 ]; then
    echo ""
    hr
    echo ""
    echo -e "  ${BOLD}What happens next${NC}"
    echo ""
    echo -e "  Structure is ready. Now the docs need content."
    echo ""
    echo -e "  ${G}/reflect 2${NC} will mine your conversation history and:"
    echo "    . Find commands you run repeatedly -> playbook"
    echo "    . Find corrections you made        -> playbook rule"
    echo "    . Find things you re-explained      -> add to docs"
    echo "    . Find context overflows            -> trim L0"
    echo "    . Build a routing table             -> add to L0"
    echo ""
    echo -e "  The more history you have, the better the playbooks."
    echo -e "  Run ${G}/reflect 2${NC} in a Claude Code session after setup finishes."
    echo ""
    if [ ${#SETUP_PROJECTS[@]} -gt 1 ]; then
      echo -e "  Run it once per project:"
      for dir in "${SETUP_PROJECTS[@]}"; do
        project=$(basename "$dir")
        echo -e "    ${DIM}cd $dir && /reflect 2${NC}"
      done
      echo ""
    fi
    pause
  fi

fi  # end if projects found

fi  # end SKIP_TO_FEEDBACK

# ═══════════════════════════════════════════════════════════════
# STEP 5: Feedback loop
# ═══════════════════════════════════════════════════════════════

hr
echo ""
echo -e "  ${BOLD}Feedback Loop${NC}"
echo ""
echo -e "  Makes your docs self-improving:"
echo ""
echo -e "    ${G}SessionEnd hook${NC}  Runs after every session. Detects"
echo -e "                      corrections, frustrations, context overflows."
echo ""
echo -e "    ${G}/reflect${NC}         You run it when you want docs to improve."
echo -e "                      Three levels. Always reversible."
echo ""

if confirm "Install the feedback loop?"; then
  echo ""

  echo -e "  ${G}[1/3]${NC} Installing SessionEnd hook..."
  mkdir -p "$CLAUDE_DIR/hooks"
  cp "$SCRIPT_DIR/feedback-loop/session-end-log.sh" "$CLAUDE_DIR/hooks/session-end-log.sh"
  chmod +x "$CLAUDE_DIR/hooks/session-end-log.sh"
  echo "    -> $CLAUDE_DIR/hooks/session-end-log.sh"

  SETTINGS="$CLAUDE_DIR/settings.json"
  if [ -f "$SETTINGS" ] && grep -q "SessionEnd" "$SETTINGS" 2>/dev/null; then
    echo "    -> Hook already in settings.json"
  else
    echo "    Configuring hook in settings.json..."
    # Auto-install the hook config
    HOOK_CMD="$CLAUDE_DIR/hooks/session-end-log.sh"
    if [ -f "$SETTINGS" ]; then
      # Merge into existing settings
      cp "$SETTINGS" "$SETTINGS.bak"
      python3 -c "
import json, sys
with open('$SETTINGS') as f:
    settings = json.load(f)
settings.setdefault('hooks', {})
settings['hooks']['SessionEnd'] = [{'hooks': [{'type': 'command', 'command': '$HOOK_CMD', 'timeout': 15}]}]
with open('$SETTINGS', 'w') as f:
    json.dump(settings, f, indent=2)
print('    -> Updated settings.json (backup at settings.json.bak)')
" 2>/dev/null || {
        echo -e "  ${Y}NOTE:${NC} Could not auto-configure. Add this to $SETTINGS:"
        echo ""
        echo "    \"hooks\": { \"SessionEnd\": [{ \"hooks\": [{ \"type\": \"command\", \"command\": \"$HOOK_CMD\", \"timeout\": 15 }]}]}"
        echo ""
      }
    else
      # Create new settings file
      python3 -c "
import json
settings = {'hooks': {'SessionEnd': [{'hooks': [{'type': 'command', 'command': '$HOOK_CMD', 'timeout': 15}]}]}}
with open('$SETTINGS', 'w') as f:
    json.dump(settings, f, indent=2)
print('    -> Created settings.json')
" 2>/dev/null
    fi
  fi

  echo -e "  ${G}[2/3]${NC} Installing /reflect..."
  mkdir -p "$CLAUDE_DIR/skills/reflect"
  sed "s|MYCELIUM_DIR|$SCRIPT_DIR|g" "$SCRIPT_DIR/feedback-loop/reflect-skill/SKILL.md" > "$CLAUDE_DIR/skills/reflect/SKILL.md"
  echo "    -> /reflect (3 levels + undo + dry-run)"

  echo -e "  ${G}[3/3]${NC} Session history..."
  HISTORY="$CLAUDE_DIR/session-history.jsonl"
  if [ -f "$HISTORY" ] && [ -s "$HISTORY" ]; then
    TOTAL=$(wc -l < "$HISTORY")
    FLAGGED=$(grep -c '"needs_review":true' "$HISTORY" 2>/dev/null || echo 0)
    echo "    -> $TOTAL sessions logged, $FLAGGED flagged"
  else
    echo "    -> Starts logging from your next session."
  fi

  echo -e "\n  ${G}Feedback loop installed.${NC}"
else
  echo "  Skipped. Run ./setup.sh --feedback-only later."
fi

# ═══════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════

echo ""
hr
echo ""
echo -e "  ${BOLD}Setup Complete${NC}"
echo ""
echo -e "  ${BOLD}${G}NEXT STEP:${NC} Open a Claude Code session and run:"
echo ""
echo -e "    ${G}/reflect 2${NC}"
echo ""
echo "  This mines your conversation history and builds real playbooks"
echo "  from your actual usage patterns, corrections, and workflows."
echo "  The more sessions you have, the better the playbooks."
echo ""
hr
echo ""
echo -e "  ${G}Ongoing workflow:${NC}"
echo "    1. Use your AI coding tool normally"
echo "    2. After important sessions: /reflect"
echo "    3. Weekly deep analysis: /reflect 2"
echo "    4. Validate structure: python3 validate.py ~/project"
echo ""
echo -e "  ${G}Safety:${NC}"
echo "    /reflect undo     Undo last reflect"
echo "    /reflect dry-run  Preview changes before applying"
echo ""
echo -e "  ${G}Tools:${NC}"
echo "    python3 validate.py ~/project    Check for problems"
echo "    python3 build-viewer.py          Rebuild HTML viewer"
echo ""
echo -e "  ${DIM}License: Anti-Capitalist Software License v1.4${NC}"
echo ""
