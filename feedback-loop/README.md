# Feedback Loop

Makes your pyramid documentation self-improving. Two pieces: a hook that logs sessions, and `/reflect` that reads them and improves docs.

## Install

```bash
cd ~/mycelium
./setup.sh                  # Full wizard (includes feedback loop)
./setup.sh --feedback-only  # Just the feedback loop
./setup.sh --uninstall      # Remove everything
```

## How It Works

```
Every session ends
       │
       ↓
SessionEnd hook fires automatically
  • Logs metadata: timestamp, project, message/tool counts
  • Detects friction signals: corrections, frustrations, repeated reads, retry loops
  • Computes a friction score — high-score sessions get flagged for review
       │
       ↓
~/.claude/session-history.jsonl accumulates session records
       │
       ↓
You run /reflect (whenever you want)
  • AI reads the actual conversations (prioritizes high-friction sessions)
  • Thinks: "What context at the start would have made this go better?"
  • Edits playbooks, references, CLAUDE.local.md
  • Marks sessions as reviewed
       │
       ↓
Docs are better → next session is better → repeat
       │
       ↓
health-check.py measures whether it's actually working
```

**Hook detects friction. /reflect fixes the cause. Health check proves it's working.**

The hook detects five friction signals: **corrections** ("no, not that"), **frustrations** ("still broken"), **reexplanations** (user repeating themselves), **repeated reads** (same file read 3+ times), and **retry loops** (same tool+target retried). Sessions scoring 10+ get `needs_review: true` so `/reflect` knows where to focus.

## /reflect — Three Levels

```
/reflect          # Level 1 (default) — quick fixes to existing docs
/reflect 2        # Level 2 — deep replay, restructure playbooks
/reflect 3        # Level 3 — rethink the framework itself
```

### Level 1 — Quick Reflect (daily use)

Reads recent unreviewed sessions, identifies knowledge gaps, applies fixes to existing playbooks and references. Fast, safe, no structural changes.

### Level 2 — Deep Analysis (weekly/monthly)

Reads full session history for a project. Looks for patterns across many sessions. Can restructure playbooks — merge, split, create new ones, rewrite the routing table.

### Level 3 — Architectural Rethink (contributors only)

Questions the framework itself. Can modify the hook, /reflect, templates, anything.

## Troubleshooting the Hook

If `/reflect` shows 0 sessions after many conversations, the hook may be failing:

```bash
# Verify hook is installed
cat ~/.claude/settings.json | jq '.hooks.SessionEnd'

# Test with a fake session
echo '{"session_id":"test","cwd":"/tmp","reason":"test"}' | \
  timeout 15 ~/.claude/hooks/session-end-log.sh

# Check recent entries
tail -3 ~/.claude/session-history.jsonl | jq .

# Clean up test entries
python3 -c "
import json
lines = [l for l in open('$HOME/.claude/session-history.jsonl')
         if 'test' != json.loads(l).get('session_id')]
open('$HOME/.claude/session-history.jsonl', 'w').write(''.join(lines))
"
```

## Tools

### health-check.py — Measure effectiveness

```bash
python3 health-check.py              # Full report: trends, per-project, signal breakdown
python3 health-check.py --brief      # One-line summary with 2-week trend
python3 health-check.py --backfill   # Recompute scores for all sessions
```

### read-session.py — Explore session history

```bash
python3 read-session.py SESSION_ID         # Read a session conversation
python3 read-session.py --recent 10        # List 10 most recent sessions
python3 read-session.py --search RabbitMQ  # Search all sessions for a keyword
python3 read-session.py --summary          # Overview by project with friction counts
python3 read-session.py FILE --tail 20     # Last 20 messages of a session
```

## Files

```
feedback-loop/
├── session-end-log.sh      # SessionEnd hook — logs metadata + detects friction signals
├── read-session.py         # Read/search session conversations
├── health-check.py         # Measure whether the system is actually helping
├── reflect-skill/
│   └── SKILL.md            # /reflect command (3 levels + undo + dry-run)
└── README.md               # This file
```

## Adapting for Your Project

1. Edit `session-end-log.sh` — change the `PROJECT` case statement to match your directories
2. Edit `SKILL.md` — adjust the doc search paths to match where your pyramid lives
3. Run `./setup.sh --feedback-only`
4. Use Claude Code normally. Run `/reflect` when you want docs to improve.
