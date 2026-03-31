#!/usr/bin/env python3
"""
Read a session conversation in human-readable format.

Usage:
  python3 read-session.py SESSION_ID          # by session ID (partial match)
  python3 read-session.py /path/to/file.jsonl # by file path
  python3 read-session.py --recent N          # show N most recent sessions
  python3 read-session.py --search TERM       # search all sessions for keyword
  python3 read-session.py --summary           # overview by project with counts

Options:
  --short    Truncate messages to 300 chars (default: 500)
  --long     Show full messages (no truncation)
  --meta     Show only metadata, no conversation
  --tail N   Show only the last N messages (useful for long sessions)
  --search TERM  Search session content for keyword matches
  --summary  Show overview grouped by project
"""

import json
import os
import sys
import glob
import re

HOME = os.path.expanduser("~")
HISTORY_FILE = os.path.join(HOME, ".claude", "session-history.jsonl")


def load_history():
    if not os.path.exists(HISTORY_FILE):
        return []
    return [json.loads(l) for l in open(HISTORY_FILE) if l.strip()]


def find_session_file(session_id):
    """Find a session file by partial ID match."""
    for f in glob.glob(os.path.join(HOME, ".claude", "projects", "*", "*.jsonl")):
        basename = os.path.basename(f).replace(".jsonl", "")
        if basename.startswith(session_id) or session_id in basename:
            return f
    return None


def extract_text_from_session(filepath):
    """Extract all user and assistant text from a session file."""
    texts = []
    if not os.path.exists(filepath):
        return texts
    try:
        for raw in open(filepath):
            try:
                obj = json.loads(raw)
            except:
                continue
            msg_type = obj.get("type")
            if msg_type not in ("user", "assistant"):
                continue
            content = obj.get("message", {}).get("content", "")
            if isinstance(content, str):
                texts.append((msg_type, content))
            elif isinstance(content, list):
                for block in content:
                    if isinstance(block, dict):
                        if block.get("type") == "text":
                            texts.append((msg_type, block.get("text", "")))
    except:
        pass
    return texts


def search_sessions(term, history):
    """Search all session files for a keyword."""
    term_re = re.compile(re.escape(term), re.IGNORECASE)
    results = []

    for session in history:
        sf = session.get("session_file", "")
        if not sf or not os.path.exists(sf):
            continue

        matches = []
        texts = extract_text_from_session(sf)
        for role, text in texts:
            if term_re.search(text):
                # Get a snippet around the match
                match = term_re.search(text)
                start = max(0, match.start() - 60)
                end = min(len(text), match.end() + 60)
                snippet = text[start:end].replace("\n", " ").strip()
                if start > 0:
                    snippet = "..." + snippet
                if end < len(text):
                    snippet = snippet + "..."
                matches.append((role, snippet))

        if matches:
            results.append((session, matches))

    return results


def read_conversation(filepath, max_chars=500, tail=0):
    """Extract user/assistant conversation from a session JSONL file."""
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        return

    messages = []
    for raw in open(filepath):
        try:
            obj = json.loads(raw)
        except:
            continue

        msg_type = obj.get("type")
        if msg_type not in ("user", "assistant"):
            continue

        content = obj.get("message", {}).get("content", "")

        texts = []
        if isinstance(content, str):
            if len(content) > 15 and not content.startswith("<"):
                texts.append(content)
        elif isinstance(content, list):
            for block in content:
                if isinstance(block, dict):
                    if block.get("type") == "text":
                        t = block.get("text", "")
                        if len(t) > 15 and not t.startswith("<"):
                            texts.append(t)
                    elif block.get("type") == "tool_use":
                        name = block.get("name", "")
                        inp = block.get("input", {})
                        if name == "Read":
                            texts.append(f"[tool: Read {inp.get('file_path', '')}]")
                        elif name == "Edit":
                            texts.append(f"[tool: Edit {inp.get('file_path', '')}]")
                        elif name == "Bash":
                            cmd = inp.get("command", "")[:100]
                            texts.append(f"[tool: Bash `{cmd}`]")
                        elif name == "Write":
                            texts.append(f"[tool: Write {inp.get('file_path', '')}]")
                        elif name == "Grep":
                            texts.append(f"[tool: Grep '{inp.get('pattern', '')}']")

        for text in texts:
            messages.append((msg_type, text))

    if tail > 0:
        messages = messages[-tail:]

    for msg_type, text in messages:
        if max_chars and max_chars > 0 and len(text) > max_chars:
            text = text[:max_chars] + "..."
        role = "USER" if msg_type == "user" else "ASST"
        print(f"[{role}] {text}")
        print()

    if not messages:
        print("(no readable messages found)")


def show_recent(n):
    """Show N most recent sessions."""
    sessions = load_history()
    sessions.sort(key=lambda s: s.get("timestamp", ""), reverse=True)
    for s in sessions[:n]:
        rev = "R" if s.get("reviewed") else " "
        score = s.get("score", 0)
        score_str = f"score={score:3d}" if score else "          "
        print(
            f"  {s.get('timestamp', '?')[:19]}  {rev} {s.get('project', '?'):20s} "
            f"msgs={s.get('user_messages', 0):3d}  tools={s.get('tool_calls', 0):4d}  "
            f"{score_str}  id={s.get('session_id', '?')[:12]}"
        )


def show_summary():
    """Show overview grouped by project."""
    from collections import Counter, defaultdict
    sessions = load_history()

    projects = defaultdict(lambda: {"total": 0, "unreviewed": 0, "high_friction": 0, "msgs": 0})
    for s in sessions:
        p = s.get("project", "unknown")
        projects[p]["total"] += 1
        projects[p]["msgs"] += s.get("user_messages", 0)
        if not s.get("reviewed", False):
            projects[p]["unreviewed"] += 1
        if s.get("needs_review") or s.get("score", 0) >= 10:
            projects[p]["high_friction"] += 1

    print(f"Total sessions: {len(sessions)}")
    print(f"\n{'Project':<25s} {'Total':>6s} {'Unrev':>6s} {'Friction':>9s} {'Msgs':>6s}")
    print("-" * 55)
    for p in sorted(projects.keys(), key=lambda x: projects[x]["unreviewed"], reverse=True):
        d = projects[p]
        print(f"{p:<25s} {d['total']:>6d} {d['unreviewed']:>6d} {d['high_friction']:>9d} {d['msgs']:>6d}")


def main():
    args = sys.argv[1:]

    if not args:
        print(__doc__)
        return

    max_chars = 500
    meta_only = False
    tail = 0

    if "--short" in args:
        max_chars = 300
        args.remove("--short")
    if "--long" in args:
        max_chars = 0
        args.remove("--long")
    if "--meta" in args:
        meta_only = True
        args.remove("--meta")
    if "--tail" in args:
        idx = args.index("--tail")
        tail = int(args[idx + 1]) if idx + 1 < len(args) else 50
        args.pop(idx + 1)
        args.pop(idx)

    if "--summary" in args:
        show_summary()
        return

    if "--search" in args:
        idx = args.index("--search")
        if idx + 1 >= len(args):
            print("Usage: --search TERM")
            return
        term = args[idx + 1]
        sessions = load_history()
        results = search_sessions(term, sessions)
        if not results:
            print(f"No sessions found matching '{term}'")
            return
        print(f"Found {len(results)} sessions matching '{term}':\n")
        for session, matches in results:
            ts = session.get("timestamp", "?")[:19]
            proj = session.get("project", "?")
            msgs = session.get("user_messages", 0)
            sid = session.get("session_id", "?")[:12]
            rev = "R" if session.get("reviewed") else " "
            print(f"  {rev} {ts} | {proj:20s} | {msgs:3d} msgs | {sid}...")
            for role, snippet in matches[:3]:  # show max 3 matches per session
                tag = "USER" if role == "user" else "ASST"
                print(f"    [{tag}] {snippet}")
            if len(matches) > 3:
                print(f"    ... and {len(matches) - 3} more matches")
            print()
        return

    if "--recent" in args:
        idx = args.index("--recent")
        n = int(args[idx + 1]) if idx + 1 < len(args) else 10
        show_recent(n)
        return

    target = args[0]

    # Is it a file path?
    if os.path.exists(target):
        filepath = target
    else:
        filepath = find_session_file(target)
        if not filepath:
            sessions = load_history()
            matches = [s for s in sessions if target in s.get("session_id", "")]
            if matches:
                filepath = matches[0].get("session_file", "")
                if not filepath or not os.path.exists(filepath):
                    print(f"Session found in history but file missing: {filepath}")
                    return
            else:
                print(f"No session found matching: {target}")
                return

    # Show metadata from history if available
    sessions = load_history()
    basename = os.path.basename(filepath).replace(".jsonl", "")
    meta = next((s for s in sessions if s.get("session_id") == basename), None)
    if meta:
        print(f"Session: {meta.get('session_id', '?')}")
        proj_info = f"Project: {meta.get('project', '?')}  Messages: {meta.get('user_messages', '?')}  Tools: {meta.get('tool_calls', '?')}"
        score = meta.get('score', 0)
        if score:
            proj_info += f"  Score: {score}"
        print(proj_info)
        print(f"Reviewed: {meta.get('reviewed', False)}")
        signals = meta.get('signals', {})
        if any(v for v in signals.values()):
            sig_parts = [f"{k}={v}" for k, v in signals.items() if v]
            print(f"Signals: {', '.join(sig_parts)}")
        print("---")

    if not meta_only:
        read_conversation(filepath, max_chars, tail=tail)


if __name__ == "__main__":
    main()
