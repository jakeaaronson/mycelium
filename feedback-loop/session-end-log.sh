#!/bin/bash
# SessionEnd hook — logs session metadata for /reflect.
# Runs automatically at the end of every Claude Code session.
# Detects friction signals so /reflect can prioritize high-friction sessions.

set -eo pipefail

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // "unknown"')
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LOG_FILE="$HOME/.claude/session-history.jsonl"

# Determine project from cwd
if [ "$CWD" = "$HOME" ]; then
  PROJECT="home"
else
  PROJECT=$(basename "$CWD")
fi

# Find session JSONL file
SESSION_FILE=""
for dir in "$HOME/.claude/projects/"*/; do
  if [ -f "${dir}${SESSION_ID}.jsonl" ]; then
    SESSION_FILE="${dir}${SESSION_ID}.jsonl"
    break
  fi
done

# Get counts + detect friction signals
ANALYSIS=$(python3 -c "
import json, sys, re
from collections import Counter

session_file = '$SESSION_FILE'
msgs = 0
tools = 0
compactions = 0

# Signal counters
corrections = 0
frustrations = 0
reexplanations = 0
repeated_reads = 0
retry_loops = 0

# Tracking for pattern detection
read_files = Counter()
tool_targets = []  # (tool_name, target) for retry detection
prev_user_texts = []

# Patterns
CORRECTION_RE = re.compile(
    r'\b(no[, ]+not|that.s not|wrong|don.t do|stop doing|actually[, ]+I|'
    r'I said|I meant|that.s incorrect|please don.t|I already told you|'
    r'not what I asked|you misunderstood)\b', re.I
)
FRUSTRATION_RE = re.compile(
    r'\b(still broken|still not working|still failing|keep trying|keep iterating|'
    r'try again|doesn.t work|isn.t working|same error|same issue|'
    r'this is wrong|come on|why (is|does|did) it)\b', re.I
)

if not session_file:
    print(json.dumps({
        'user_messages': 0, 'tool_calls': 0, 'compactions': 0,
        'signals': {
            'corrections': 0, 'frustrations': 0, 'reexplanations': 0,
            'repeated_reads': 0, 'retry_loops': 0
        }
    }))
    sys.exit(0)

try:
    for raw in open(session_file):
        try:
            obj = json.loads(raw)
        except:
            continue

        t = obj.get('type')

        if t == 'user':
            content = obj.get('message', {}).get('content', '')
            if isinstance(content, list):
                full_text = ' '.join(
                    b.get('text', '') for b in content
                    if isinstance(b, dict) and b.get('type') == 'text'
                )
            else:
                full_text = str(content)

            # Skip skill invocations
            if '<command-name>' in full_text:
                continue

            msgs += 1

            # Detect corrections
            if CORRECTION_RE.search(full_text):
                corrections += 1

            # Detect frustrations
            if FRUSTRATION_RE.search(full_text):
                frustrations += 1

            # Detect reexplanations (user repeating similar text within 5 messages)
            text_lower = full_text.lower().strip()[:200]
            if len(text_lower) > 30:
                for prev in prev_user_texts[-5:]:
                    # Simple overlap check: if >60% of words match
                    words_now = set(text_lower.split())
                    words_prev = set(prev.split())
                    if len(words_now) > 3 and len(words_prev) > 3:
                        overlap = len(words_now & words_prev) / min(len(words_now), len(words_prev))
                        if overlap > 0.6:
                            reexplanations += 1
                            break
                prev_user_texts.append(text_lower)

        elif t == 'assistant':
            content = obj.get('message', {}).get('content', [])
            if isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get('type') == 'tool_use':
                        tools += 1
                        name = block.get('name', '')
                        inp = block.get('input', {})

                        # Track file reads for repeated_reads
                        if name == 'Read':
                            fp = inp.get('file_path', '')
                            if fp:
                                read_files[fp] += 1

                        # Track tool targets for retry_loops
                        target = ''
                        if name in ('Read', 'Edit', 'Write'):
                            target = inp.get('file_path', '')
                        elif name == 'Bash':
                            target = inp.get('command', '')[:80]
                        if target:
                            tool_targets.append((name, target))

        elif t == 'summary':
            compactions += 1

except Exception:
    pass

# Count repeated reads (files read 3+ times)
repeated_reads = sum(1 for f, c in read_files.items() if c >= 3)

# Count retry loops (same tool+target appearing 3+ times in a window of 10)
retry_count = 0
for i in range(len(tool_targets)):
    window = tool_targets[max(0, i-9):i+1]
    current = tool_targets[i]
    if sum(1 for t in window if t == current) >= 3:
        retry_count += 1
retry_loops = min(retry_count, 20)  # cap to avoid inflation

print(json.dumps({
    'user_messages': msgs,
    'tool_calls': tools,
    'compactions': compactions,
    'signals': {
        'corrections': corrections,
        'frustrations': frustrations,
        'reexplanations': reexplanations,
        'repeated_reads': repeated_reads,
        'retry_loops': retry_loops
    }
}))
" 2>/dev/null || echo '{"user_messages":0,"tool_calls":0,"compactions":0,"signals":{"corrections":0,"frustrations":0,"reexplanations":0,"repeated_reads":0,"retry_loops":0}}')

MSG_COUNT=$(echo "$ANALYSIS" | jq -r '.user_messages // 0')
TOOL_CALLS=$(echo "$ANALYSIS" | jq -r '.tool_calls // 0')
COMPACTIONS=$(echo "$ANALYSIS" | jq -r '.compactions // 0')
SIGNALS=$(echo "$ANALYSIS" | jq -c '.signals // {}')
TOTAL_SIGNALS=$(echo "$SIGNALS" | jq '[.[]] | add // 0')

# Skip zero-message sessions
if [ "$MSG_COUNT" -eq 0 ] 2>/dev/null; then
  exit 0
fi

# Deduplicate: skip if session_id already exists in history
if grep -q "\"session_id\":\"$SESSION_ID\"" "$LOG_FILE" 2>/dev/null; then
  exit 0
fi

# Compute score (higher = more friction = higher review priority)
SCORE=$(echo "$SIGNALS" | jq '(.corrections * 10) + (.frustrations * 15) + (.reexplanations * 5) + (.repeated_reads * 3) + (.retry_loops * 2)')
NEEDS_REVIEW=$([ "$SCORE" -ge 10 ] 2>/dev/null && echo "true" || echo "false")

# Write to history
jq -n -c \
  --arg ts "$TIMESTAMP" \
  --arg sid "$SESSION_ID" \
  --arg cwd "$CWD" \
  --arg project "$PROJECT" \
  --argjson msgs "$MSG_COUNT" \
  --argjson tools "$TOOL_CALLS" \
  --argjson compactions "$COMPACTIONS" \
  --argjson signals "$SIGNALS" \
  --argjson score "$SCORE" \
  --argjson total_signals "$TOTAL_SIGNALS" \
  --argjson needs_review "$NEEDS_REVIEW" \
  --arg session_file "$SESSION_FILE" \
  '{
    timestamp: $ts,
    session_id: $sid,
    cwd: $cwd,
    project: $project,
    user_messages: $msgs,
    tool_calls: $tools,
    compactions: $compactions,
    signals: $signals,
    score: $score,
    total_signals: $total_signals,
    needs_review: $needs_review,
    reviewed: false,
    session_file: $session_file
  }' >> "$LOG_FILE"

exit 0
