#!/usr/bin/env python3
"""
Backfill session-history.jsonl from existing Claude Code session files.
Run once to populate history from sessions that predate the SessionEnd hook.

Usage: python3 backfill-history.py
"""

import json
import os
import glob
import re

HOME = os.path.expanduser("~")
HISTORY_FILE = os.path.join(HOME, ".claude", "session-history.jsonl")

PROJECT_MAP = {
    "-home-jacob-activecomply-api": "activecomply-api",
    "-home-jacob-dashboard-app": "dashboard-app",
    "-home-jacob-survey-app": "survey-app",
    "-home-jacob-thezeitgeistexperiment": "zeitgeist",
    "-home-jacob-mnt-agent-house-home-jacob-inkmans-brain": "inkmans-brain",
    "-home-jacob": "home",
}

# Load existing session IDs to avoid duplicates
existing_ids = set()
if os.path.exists(HISTORY_FILE):
    with open(HISTORY_FILE) as f:
        for line in f:
            try:
                obj = json.loads(line.strip())
                existing_ids.add(obj.get("session_id"))
            except:
                pass

count = 0
skipped = 0

for jsonl_path in sorted(glob.glob(os.path.join(HOME, ".claude", "projects", "*", "*.jsonl"))):
    # Skip subagent files
    if "/subagents/" in jsonl_path:
        continue

    session_id = os.path.basename(jsonl_path).replace(".jsonl", "")
    if session_id in existing_ids:
        skipped += 1
        continue

    project_dir = os.path.basename(os.path.dirname(jsonl_path))
    project = PROJECT_MAP.get(project_dir, "unknown")

    # Extract basic metrics
    msg_count = 0
    compactions = 0
    tool_calls = 0
    first_ts = None
    cwd = None

    try:
        with open(jsonl_path) as f:
            for line in f:
                try:
                    obj = json.loads(line.strip())
                    if obj.get("type") == "user":
                        content = obj.get("message", {}).get("content", "")
                        if isinstance(content, str) and len(content) > 5:
                            msg_count += 1
                        elif isinstance(content, list):
                            for c in content:
                                if isinstance(c, dict) and c.get("type") == "text" and len(c.get("text", "")) > 5:
                                    msg_count += 1
                                    break
                    if obj.get("type") == "assistant":
                        content = obj.get("message", {}).get("content", [])
                        if isinstance(content, list):
                            for c in content:
                                if isinstance(c, dict) and c.get("type") == "tool_use":
                                    tool_calls += 1
                    # Check for compactions
                    raw = line.lower()
                    if "compacted" in raw or "continued from a previous" in raw:
                        compactions += 1
                    # Get timestamp and cwd from first message
                    if not first_ts and "timestamp" in line:
                        ts = obj.get("timestamp")
                        if ts:
                            first_ts = ts
                    if not cwd:
                        cwd = obj.get("cwd")
                except:
                    pass
    except:
        continue

    record = {
        "timestamp": first_ts or "unknown",
        "session_id": session_id,
        "cwd": cwd or "unknown",
        "project": project,
        "reason": "backfill",
        "user_messages": msg_count,
        "compactions": compactions,
        "tool_calls": tool_calls,
        "session_file": jsonl_path,
        "analyzed": False,
    }

    with open(HISTORY_FILE, "a") as f:
        f.write(json.dumps(record) + "\n")
    count += 1

print(f"Backfilled {count} sessions ({skipped} already existed)")
print(f"History file: {HISTORY_FILE}")
