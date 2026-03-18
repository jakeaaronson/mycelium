#!/usr/bin/env python3
"""
Session history reporting tool. Reads ~/.claude/session-history.jsonl
and prints metrics. The actual analysis is done by /reflect.

Usage:
  python3 analyze-sessions.py            # Full report
  python3 analyze-sessions.py --project X  # Filter by project
"""

import json
import os
import sys
import argparse
from collections import Counter

HISTORY_FILE = os.path.expanduser("~/.claude/session-history.jsonl")


def load():
    if not os.path.exists(HISTORY_FILE):
        print(f"No history at {HISTORY_FILE}")
        return []
    sessions = []
    with open(HISTORY_FILE) as f:
        for line in f:
            try:
                sessions.append(json.loads(line.strip()))
            except:
                pass
    return sessions


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", help="Filter by project")
    args = parser.parse_args()

    sessions = load()
    if not sessions:
        return

    if args.project:
        sessions = [s for s in sessions if s.get("project") == args.project]

    total = len(sessions)
    flagged = sum(1 for s in sessions if s.get("needs_review"))
    reviewed = sum(1 for s in sessions if s.get("reviewed"))
    pending = sum(1 for s in sessions if s.get("needs_review") and not s.get("reviewed"))
    total_msgs = sum(s.get("user_messages", 0) for s in sessions)
    total_compactions = sum(s.get("compactions", 0) for s in sessions)
    by_project = Counter(s.get("project", "unknown") for s in sessions)

    # Signal totals
    total_corrections = sum(s.get("signals", {}).get("corrections", 0) for s in sessions)
    total_reexplain = sum(s.get("signals", {}).get("reexplanations", 0) for s in sessions)
    total_frustrations = sum(s.get("signals", {}).get("frustrations", 0) for s in sessions)
    total_overflows = sum(s.get("signals", {}).get("overflows", 0) for s in sessions)
    total_signals = total_corrections + total_reexplain + total_frustrations + total_overflows

    # Scores
    scores = [s.get("score", 0) for s in sessions if s.get("score", 0) > 0]
    avg_score = sum(scores) / len(scores) if scores else 0

    timestamps = [s.get("timestamp", "") for s in sessions if s.get("timestamp")]
    date_range = f"{min(timestamps)[:10]} to {max(timestamps)[:10]}" if timestamps else "unknown"

    print(f"""
{'='*55}
  PYRAMID FEEDBACK LOOP — STATUS REPORT
{'='*55}

  Sessions:        {total} total, {flagged} flagged, {reviewed} reviewed
  Pending review:  {pending} sessions (run /reflect to process)
  Date range:      {date_range}
  User messages:   {total_msgs}

  SIGNAL SUMMARY
  ─────────────────────────────────────
  Corrections:     {total_corrections:4d}  (model made wrong assumption)
  Re-explanations: {total_reexplain:4d}  (user repeated known info)
  Frustrations:    {total_frustrations:4d}  (user got stuck/confused)
  Context overflow: {total_overflows:4d}  (session hit limits)
  ─────────────────────────────────────
  Total signals:   {total_signals:4d}

  HEALTH METRICS
  ─────────────────────────────────────
  Compaction rate:  {total_compactions/max(total,1)*100:.0f}% of sessions hit context limits
  Avg signal score: {avg_score:.0f}/100 (lower = healthier docs)
  Flag rate:        {flagged/max(total,1)*100:.0f}% of sessions had signals

  BY PROJECT""")

    for proj, count in by_project.most_common():
        proj_sessions = [s for s in sessions if s.get("project") == proj]
        proj_flagged = sum(1 for s in proj_sessions if s.get("needs_review"))
        proj_pending = sum(1 for s in proj_sessions if s.get("needs_review") and not s.get("reviewed"))
        print(f"    {proj:20s}  {count:3d} sessions, {proj_flagged:2d} flagged, {proj_pending:2d} pending")

    print(f"""
{'='*55}
""")

    if pending > 0:
        print(f"  → {pending} sessions need review. Run /reflect in Claude Code.")
    else:
        print(f"  → All clean. No sessions need review.")


if __name__ == "__main__":
    main()
