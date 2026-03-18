# Feedback Loop

Makes your pyramid documentation self-improving. Two pieces.

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
  • Logs session metadata
  • Detects signals (corrections, re-explanations, frustrations, overflows)
  • Scores session 0-100
  • Flags sessions with signals as needs_review: true
       │
       ↓
~/.claude/session-history.jsonl accumulates flagged sessions
       │
       ↓
You run /reflect (whenever you want)
  • Claude reads ALL flagged sessions
  • Understands what went wrong (not just keywords — full comprehension)
  • Edits playbooks, references, CLAUDE.md
  • Marks sessions as reviewed
       │
       ↓
Docs are better → next session is better → fewer signals → repeat
```

**That's it. Hook logs and flags. /reflect reads and fixes.**

## The Hook — What It Detects

The SessionEnd hook runs pattern matching on every session's user messages:

| Signal | What It Catches | Score Weight |
|--------|----------------|-------------|
| Corrections | "no not that", "wrong file", "actually..." | +15 each |
| Re-explanations | "remember we always...", "as I said..." | +20 each |
| Frustrations | "why is it...", "still broken", "try again" | +10 each |
| Context overflows | "continued from previous conversation" | +25 each |
| Compactions | Context window hit limit | +15 |

Sessions scoring >0 are flagged as `needs_review: true`.

## /reflect — Three Levels

```
/reflect          # Level 1 (default) — quick fixes to existing docs
/reflect 2        # Level 2 — deep replay, restructure playbooks
/reflect 3        # Level 3 — rethink the framework itself
```

### Level 1 — Quick Reflect (daily use)

Reads flagged sessions, applies obvious fixes to existing playbooks and references. Fast, safe, no structural changes. Run this after a rough session or at end of day.

```
/reflect                     # Fix docs from recent sessions
/reflect 1 zeitgeist         # Only fix zeitgeist docs
```

### Level 2 — Deep Analysis (weekly/monthly)

Replays full session history for a project. Looks for patterns across many sessions. Can restructure playbooks — merge, split, create new ones, rewrite the routing table. Run when signal scores aren't declining or when a project feels stale.

```
/reflect 2                   # Deep analysis of worst project
/reflect 2 activecomply-api  # Deep analysis of specific project
```

### Level 3 — Architectural Rethink (contributors only)

Questions the framework itself. Is the 3-level pyramid right? Are the signal patterns detecting the right things? Is 50 lines the right L0 size? Can modify templates, build scripts, the hook, /reflect itself, anything. Changes should be committed as a PR.

```
/reflect 3                   # Full framework audit
```

## Files

```
feedback-loop/
├── session-end-log.sh      # SessionEnd hook (auto, every session)
├── analyze-sessions.py     # Metrics and reporting
├── backfill-history.py     # One-time: populate history from old sessions
├── reflect-skill/
│   └── SKILL.md            # /reflect command (3 levels + undo + dry-run)
└── README.md               # This file
```

## Adapting for Your Project

1. Edit `session-end-log.sh` — change the `PROJECT` case statement to match your directories
2. Edit `SKILL.md` — adjust the doc search paths to match where your pyramid lives
3. Run `./setup.sh --feedback-only`
4. Use Claude Code normally. Run `/reflect` when you want docs to improve.
