#!/usr/bin/env python3
"""
Mycelium health check — measures whether the documentation system is helping.

Usage:
  python3 health-check.py              # full report
  python3 health-check.py --backfill   # backfill scores into session-history.jsonl
  python3 health-check.py --brief      # one-line summary for quick checks

Metrics tracked:
  - Friction score trend (are sessions getting smoother?)
  - Signal breakdown (what kinds of friction are most common?)
  - Per-project trends (which projects need attention?)
  - Efficiency ratio (tool calls per user message — lower = more autonomous)
"""

import json
import os
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime, timedelta

HOME = os.path.expanduser("~")
HISTORY_FILE = os.path.join(HOME, ".claude", "session-history.jsonl")

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


def analyze_session(session_file):
    """Run signal detection on a session file. Returns signals dict."""
    corrections = 0
    frustrations = 0
    reexplanations = 0
    read_files = Counter()
    tool_targets = []
    prev_user_texts = []
    msgs = 0
    tools = 0
    compactions = 0

    if not session_file or not os.path.exists(session_file):
        return None

    try:
        for raw in open(session_file):
            try:
                obj = json.loads(raw)
            except:
                continue

            t = obj.get("type")
            if t == "user":
                content = obj.get("message", {}).get("content", "")
                if isinstance(content, list):
                    full_text = " ".join(
                        b.get("text", "") for b in content
                        if isinstance(b, dict) and b.get("type") == "text"
                    )
                else:
                    full_text = str(content)

                if "<command-name>" in full_text:
                    continue
                msgs += 1

                if CORRECTION_RE.search(full_text):
                    corrections += 1
                if FRUSTRATION_RE.search(full_text):
                    frustrations += 1

                text_lower = full_text.lower().strip()[:200]
                if len(text_lower) > 30:
                    for prev in prev_user_texts[-5:]:
                        words_now = set(text_lower.split())
                        words_prev = set(prev.split())
                        if len(words_now) > 3 and len(words_prev) > 3:
                            overlap = len(words_now & words_prev) / min(len(words_now), len(words_prev))
                            if overlap > 0.6:
                                reexplanations += 1
                                break
                    prev_user_texts.append(text_lower)

            elif t == "assistant":
                content = obj.get("message", {}).get("content", [])
                if isinstance(content, list):
                    for block in content:
                        if isinstance(block, dict) and block.get("type") == "tool_use":
                            tools += 1
                            name = block.get("name", "")
                            inp = block.get("input", {})
                            if name == "Read":
                                fp = inp.get("file_path", "")
                                if fp:
                                    read_files[fp] += 1
                            target = ""
                            if name in ("Read", "Edit", "Write"):
                                target = inp.get("file_path", "")
                            elif name == "Bash":
                                target = inp.get("command", "")[:80]
                            if target:
                                tool_targets.append((name, target))

            elif t == "summary":
                compactions += 1
    except Exception:
        return None

    repeated_reads = sum(1 for f, c in read_files.items() if c >= 3)

    retry_count = 0
    for i in range(len(tool_targets)):
        window = tool_targets[max(0, i - 9):i + 1]
        current = tool_targets[i]
        if sum(1 for t in window if t == current) >= 3:
            retry_count += 1
    retry_loops = min(retry_count, 20)

    signals = {
        "corrections": corrections,
        "frustrations": frustrations,
        "reexplanations": reexplanations,
        "repeated_reads": repeated_reads,
        "retry_loops": retry_loops,
    }
    score = (corrections * 10) + (frustrations * 15) + (reexplanations * 5) + (repeated_reads * 3) + (retry_loops * 2)

    return {
        "user_messages": msgs,
        "tool_calls": tools,
        "compactions": compactions,
        "signals": signals,
        "score": score,
        "total_signals": sum(signals.values()),
        "needs_review": score >= 10,
    }


def backfill():
    """Backfill scores into session-history.jsonl for sessions missing signal data."""
    with open(HISTORY_FILE, "r") as f:
        lines = f.readlines()

    updated = 0
    new_lines = []
    for line in lines:
        try:
            record = json.loads(line.strip())
            # Skip if already has real signal data
            existing_signals = record.get("signals", {})
            has_signals = any(v for v in existing_signals.values()) if existing_signals else False
            has_score = record.get("score") is not None and record.get("score") != "?"

            if not has_signals or not has_score:
                result = analyze_session(record.get("session_file", ""))
                if result:
                    record["signals"] = result["signals"]
                    record["score"] = result["score"]
                    record["total_signals"] = result["total_signals"]
                    record["needs_review"] = result["needs_review"]
                    record["compactions"] = result.get("compactions", 0)
                    # Also fix user_messages/tool_calls if they were wrong
                    if result["user_messages"] > 0:
                        record["user_messages"] = result["user_messages"]
                        record["tool_calls"] = result["tool_calls"]
                    updated += 1

            new_lines.append(json.dumps(record) + "\n")
        except Exception:
            new_lines.append(line)

    with open(HISTORY_FILE, "w") as f:
        f.writelines(new_lines)

    print(f"Backfilled {updated} sessions with signal data")


def full_report():
    """Generate the full health check report."""
    sessions = []
    for line in open(HISTORY_FILE):
        try:
            sessions.append(json.loads(line.strip()))
        except:
            pass

    if not sessions:
        print("No sessions found.")
        return

    # Compute scores if missing
    for s in sessions:
        if s.get("score") is None or s.get("score") == "?":
            result = analyze_session(s.get("session_file", ""))
            if result:
                s.update(result)
            else:
                s["score"] = 0
                s["signals"] = {}

    total = len(sessions)
    scores = [s.get("score", 0) for s in sessions]
    avg_score = sum(scores) / total if total else 0

    print(f"=== Mycelium Health Check — {datetime.now().strftime('%Y-%m-%d')} ===\n")
    print(f"Sessions: {total}  |  Avg friction score: {avg_score:.1f}  |  Unreviewed: {sum(1 for s in sessions if not s.get('reviewed'))}")
    print()

    # Distribution
    buckets = {"Clean (0)": 0, "Minor (1-9)": 0, "Needs review (10-29)": 0, "High friction (30+)": 0}
    for sc in scores:
        if sc == 0: buckets["Clean (0)"] += 1
        elif sc < 10: buckets["Minor (1-9)"] += 1
        elif sc < 30: buckets["Needs review (10-29)"] += 1
        else: buckets["High friction (30+)"] += 1

    print("--- Friction Distribution ---")
    for label, count in buckets.items():
        pct = count / total * 100
        bar = "#" * int(pct / 2)
        print(f"  {label:<25s} {count:>3d} ({pct:4.1f}%)  {bar}")
    print()

    # Weekly trend
    print("--- Weekly Trend ---")
    week_data = defaultdict(lambda: {"scores": [], "msgs": [], "tools": []})
    for s in sessions:
        try:
            dt = datetime.strptime(s.get("timestamp", "")[:10], "%Y-%m-%d")
            week = dt.strftime("%Y-W%W")
            week_data[week]["scores"].append(s.get("score", 0))
            week_data[week]["msgs"].append(s.get("user_messages", 0))
            week_data[week]["tools"].append(s.get("tool_calls", 0))
        except:
            pass

    print(f"  {'Week':<10s} {'Sessions':>8s} {'Avg Score':>10s} {'Avg Msgs':>9s} {'Tool/Msg':>9s}  Trend")
    for week in sorted(week_data.keys()):
        d = week_data[week]
        n = len(d["scores"])
        avg_sc = sum(d["scores"]) / n
        avg_msgs = sum(d["msgs"]) / n
        total_msgs = sum(d["msgs"])
        total_tools = sum(d["tools"])
        ratio = total_tools / total_msgs if total_msgs else 0
        bar = "#" * int(avg_sc / 2)
        print(f"  {week:<10s} {n:>8d} {avg_sc:>10.1f} {avg_msgs:>9.1f} {ratio:>9.1f}  {bar}")
    print()

    # Per-project
    print("--- Per Project ---")
    proj_data = defaultdict(lambda: {"scores": [], "msgs": [], "tools": []})
    for s in sessions:
        p = s.get("project", "?")
        proj_data[p]["scores"].append(s.get("score", 0))
        proj_data[p]["msgs"].append(s.get("user_messages", 0))
        proj_data[p]["tools"].append(s.get("tool_calls", 0))

    print(f"  {'Project':<22s} {'N':>4s} {'Avg Score':>10s} {'Max':>5s} {'Avg Msgs':>9s} {'Tool/Msg':>9s}")
    for p in sorted(proj_data.keys(), key=lambda x: sum(proj_data[x]["scores"]) / len(proj_data[x]["scores"]), reverse=True):
        d = proj_data[p]
        n = len(d["scores"])
        avg_sc = sum(d["scores"]) / n
        max_sc = max(d["scores"])
        avg_msgs = sum(d["msgs"]) / n
        total_msgs = sum(d["msgs"])
        total_tools = sum(d["tools"])
        ratio = total_tools / total_msgs if total_msgs else 0
        print(f"  {p:<22s} {n:>4d} {avg_sc:>10.1f} {max_sc:>5d} {avg_msgs:>9.1f} {ratio:>9.1f}")
    print()

    # Signal breakdown
    print("--- Most Common Friction Types ---")
    signal_totals = Counter()
    for s in sessions:
        for k, v in s.get("signals", {}).items():
            if v:
                signal_totals[k] += v
    for sig, count in signal_totals.most_common():
        print(f"  {sig:<20s} {count:>4d} occurrences")
    print()

    # Top friction sessions (unreviewed first)
    print("--- Top 5 Friction Sessions (Unreviewed) ---")
    unreviewed_friction = sorted(
        [s for s in sessions if not s.get("reviewed") and s.get("score", 0) > 0],
        key=lambda x: x.get("score", 0), reverse=True
    )[:5]
    if unreviewed_friction:
        for s in unreviewed_friction:
            print(f"  score={s['score']:>3d}  {s.get('timestamp','')[:10]}  {s.get('project','?'):<20s}  {s.get('user_messages',0):>3d} msgs  {s.get('session_id','')[:12]}")
    else:
        print("  (none — all reviewed!)")


def brief():
    """One-line summary."""
    sessions = []
    for line in open(HISTORY_FILE):
        try:
            sessions.append(json.loads(line.strip()))
        except:
            pass

    total = len(sessions)
    unreviewed = sum(1 for s in sessions if not s.get("reviewed"))
    scores = [s.get("score", 0) for s in sessions if s.get("score") is not None and s.get("score") != "?"]
    avg = sum(scores) / len(scores) if scores else 0

    # Last 2 weeks vs prior 2 weeks
    now = datetime.now()
    recent = [s for s in sessions if s.get("timestamp", "") >= (now - timedelta(days=14)).strftime("%Y-%m-%d")]
    older = [s for s in sessions if (now - timedelta(days=28)).strftime("%Y-%m-%d") <= s.get("timestamp", "") < (now - timedelta(days=14)).strftime("%Y-%m-%d")]

    recent_avg = sum(s.get("score", 0) for s in recent) / len(recent) if recent else 0
    older_avg = sum(s.get("score", 0) for s in older) / len(older) if older else 0

    if older_avg > 0:
        delta = ((recent_avg - older_avg) / older_avg) * 100
        trend = f"{'↑' if delta > 0 else '↓'}{abs(delta):.0f}%" if abs(delta) > 5 else "→ stable"
    else:
        trend = "no baseline"

    print(f"Sessions: {total} | Unreviewed: {unreviewed} | Avg score: {avg:.1f} | Recent trend: {trend}")


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--backfill" in args:
        backfill()
    elif "--brief" in args:
        brief()
    else:
        full_report()
