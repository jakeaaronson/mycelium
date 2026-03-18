#!/bin/bash
# SessionEnd hook — logs session, detects signals, flags for /reflect.
# Runs automatically at the end of every Claude Code session.

set -euo pipefail

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // "unknown"')
REASON=$(echo "$INPUT" | jq -r '.reason // "unknown"')
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LOG_FILE="$HOME/.claude/session-history.jsonl"

# Determine project from cwd
PROJECT="unknown"
case "$CWD" in
  */activecomply-api*) PROJECT="activecomply-api" ;;
  */dashboard-app*) PROJECT="dashboard-app" ;;
  */survey-app*) PROJECT="survey-app" ;;
  */thezeitgeistexperiment*) PROJECT="zeitgeist" ;;
  */inkmans*) PROJECT="inkmans-brain" ;;
  */dev-agents*) PROJECT="dev-agents" ;;
  */agentdepo*) PROJECT="agentdepo" ;;
  "$HOME") PROJECT="home" ;;
esac

# Find session JSONL file
SESSION_FILE=""
for dir in "$HOME/.claude/projects/"*/; do
  if [ -f "${dir}${SESSION_ID}.jsonl" ]; then
    SESSION_FILE="${dir}${SESSION_ID}.jsonl"
    break
  fi
done

# ── Extract metrics and detect signals in one pass ──
MSG_COUNT=0
COMPACTIONS=0
TOOL_CALLS=0
CORRECTIONS=0
REEXPLANATIONS=0
FRUSTRATIONS=0
OVERFLOWS=0
REPEATED_READS=0
CORRECTIONS=0
REEXPLANATIONS=0
FRUSTRATIONS=0
OVERFLOWS=0

if [ -n "$SESSION_FILE" ] && [ -f "$SESSION_FILE" ]; then
  # Count messages and tool calls
  MSG_COUNT=$(grep -c '"type":"user"' "$SESSION_FILE" 2>/dev/null || echo 0)
  TOOL_CALLS=$(grep -c '"tool_use"' "$SESSION_FILE" 2>/dev/null || echo 0)

  # Extract user text for signal detection
  USER_TEXT=$(python3 -c "
import json, sys
texts = []
for line in open('$SESSION_FILE'):
    try:
        obj = json.loads(line)
        if obj.get('type') != 'user': continue
        c = obj.get('message',{}).get('content','')
        if isinstance(c, str) and len(c) > 10 and not c.startswith('<'):
            texts.append(c.lower())
        elif isinstance(c, list):
            for b in c:
                if isinstance(b, dict) and b.get('type') == 'text' and len(b.get('text','')) > 10:
                    t = b['text']
                    if not t.startswith('<'):
                        texts.append(t.lower())
    except: pass
print('\n'.join(texts))
" 2>/dev/null || echo "")

  # Signal detection — user messages
  CORRECTIONS=$(echo "$USER_TEXT" | grep -ciE "no[, ]+(not that|i mean)|actually[, ]|that.s (not|wrong)|you (missed|forgot|should have)|wrong (file|branch|dir)|the other (one|repo)" 2>/dev/null || echo 0)
  REEXPLANATIONS=$(echo "$USER_TEXT" | grep -ciE "remember[, ]+(that|we|the|i)|i.ve (already|told you|explained)|as i said|like (i|we) (said|discussed)|we always|we never|the convention is|the rule is" 2>/dev/null || echo 0)
  FRUSTRATIONS=$(echo "$USER_TEXT" | grep -ciE "why (is|are|did) (it|you|this)|still (not|broken|wrong)|try again|you.re (stuck|looping)" 2>/dev/null || echo 0)
  OVERFLOWS=$(echo "$USER_TEXT" | grep -ciE "continued from a previous conversation|context.*(limit|overflow|ran out)" 2>/dev/null || echo 0)
  COMPACTIONS=$(grep -ciE "compacted|PreCompact|PostCompact" "$SESSION_FILE" 2>/dev/null || echo 0)

  # Signal detection — repeated file reads (model reading same file 4+ times = needs a reference sheet)
  REPEATED_READS=$(python3 -c "
import json, sys
from collections import Counter
reads = Counter()
for line in open('$SESSION_FILE'):
    try:
        obj = json.loads(line)
        if obj.get('type') != 'assistant': continue
        content = obj.get('message', {}).get('content', [])
        if not isinstance(content, list): continue
        for c in content:
            if isinstance(c, dict) and c.get('type') == 'tool_use' and c.get('name') == 'Read':
                fp = c.get('input', {}).get('file_path', '')
                if fp: reads[fp] += 1
    except: pass
repeated = [f for f, n in reads.items() if n >= 4]
print(len(repeated))
" 2>/dev/null || echo 0)
fi

# Calculate score
SCORE=$(( CORRECTIONS * 15 + REEXPLANATIONS * 20 + FRUSTRATIONS * 10 + OVERFLOWS * 25 + REPEATED_READS * 10 + (COMPACTIONS > 0 ? 15 : 0) ))
if [ "$SCORE" -gt 100 ]; then SCORE=100; fi

TOTAL_SIGNALS=$(( CORRECTIONS + REEXPLANATIONS + FRUSTRATIONS + OVERFLOWS + REPEATED_READS ))
NEEDS_REVIEW=false
if [ "$TOTAL_SIGNALS" -gt 0 ] || [ "$COMPACTIONS" -gt 0 ]; then
  NEEDS_REVIEW=true
fi

# Write to history
jq -n -c \
  --arg ts "$TIMESTAMP" \
  --arg sid "$SESSION_ID" \
  --arg cwd "$CWD" \
  --arg project "$PROJECT" \
  --arg reason "$REASON" \
  --argjson msgs "$MSG_COUNT" \
  --argjson tools "$TOOL_CALLS" \
  --argjson compactions "$COMPACTIONS" \
  --argjson corrections "$CORRECTIONS" \
  --argjson reexplanations "$REEXPLANATIONS" \
  --argjson frustrations "$FRUSTRATIONS" \
  --argjson overflows "$OVERFLOWS" \
  --argjson repeated_reads "$REPEATED_READS" \
  --argjson score "$SCORE" \
  --argjson total_signals "$TOTAL_SIGNALS" \
  --argjson needs_review "$NEEDS_REVIEW" \
  --arg session_file "$SESSION_FILE" \
  '{
    timestamp: $ts,
    session_id: $sid,
    cwd: $cwd,
    project: $project,
    reason: $reason,
    user_messages: $msgs,
    tool_calls: $tools,
    compactions: $compactions,
    signals: {
      corrections: $corrections,
      reexplanations: $reexplanations,
      frustrations: $frustrations,
      overflows: $overflows,
      repeated_reads: $repeated_reads
    },
    score: $score,
    total_signals: $total_signals,
    needs_review: $needs_review,
    reviewed: false,
    session_file: $session_file
  }' >> "$LOG_FILE"

exit 0
