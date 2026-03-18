# Adaptation Guide

How to apply the pyramid architecture to your own projects.

## Quick Start (15 minutes)

### 1. Measure Your Current State

Count the lines in your CLAUDE.md (or equivalent). If it's over 80 lines, you'll benefit from this approach.

```bash
wc -l CLAUDE.md
```

Check your context overflow rate. If you use Claude Code:
```bash
# Count sessions that hit context limits
grep -l "continued from a previous" ~/.claude/projects/*/[!s]*.jsonl | wc -l
```

### 2. Categorize Every Section

Read your CLAUDE.md line by line. For each section, ask:

| Question | If Yes → |
|----------|----------|
| Would violating this cause a build failure or security issue? | **Keep in Level 0** |
| Is this needed in >50% of conversations? | **Keep in Level 0** |
| Is this specific to one type of task (testing, deploying, etc.)? | **Move to a playbook** |
| Is this lookup/reference material (schemas, URLs, examples)? | **Move to reference** |
| Can the model figure this out from reading the code? | **Delete it** |

### 3. Create the Directory Structure

```bash
mkdir -p docs/playbooks docs/reference
```

### 4. Write Your Routing Table

In CLAUDE.md, replace the moved sections with a routing table:

```markdown
## Before You Start

| Task | Read First |
|------|-----------|
| Writing tests | `docs/playbooks/testing.md` |
| Deploying | `docs/playbooks/deployment.md` |
```

### 5. Test It

Start a new Claude Code session. Give it a task that would have used the old documentation. See if:
- It reads the right playbook
- It follows the instructions correctly
- The conversation stays shorter

## Mining Your Conversation History

If you use Claude Code, your conversation history is stored as JSONL files:

```
~/.claude/projects/{project-path}/*.jsonl
```

Each line is a JSON object with `type` (user/assistant), `message.content`, and metadata.

### What to Look For

1. **Repeated commands** — If you or the model runs the same command in >3 sessions, it belongs in a playbook
2. **Repeated corrections** — "No, not that, do X instead" → This is a playbook rule
3. **Context re-explanations** — "Remember, we use Y for Z" → This belongs in Level 0 or a playbook
4. **Common task sequences** — Steps that always happen together → These are a playbook workflow

### Extraction Script

```python
import json, glob, os
from collections import Counter

messages = []
for f in glob.glob(os.path.expanduser("~/.claude/projects/YOUR-PROJECT/*.jsonl")):
    for line in open(f):
        obj = json.loads(line)
        if obj.get("type") == "user":
            content = obj.get("message", {}).get("content", "")
            if isinstance(content, str) and len(content) > 20:
                messages.append(content)

print(f"Total messages: {len(messages)}")
# Review these manually for patterns
for msg in messages[:50]:
    print(f"  - {msg[:120]}")
```

## Playbook Writing Tips

**Good playbook** (actionable, specific, 15 lines):
```markdown
# Playbook: Elasticsearch Reindexing

## Steps
1. Create temp index with `reindex_` prefix
2. Reindex: `POST _reindex { "source": {"index": "original"}, "dest": {"index": "reindex_original"} }`
3. Delete original: `DELETE /original`
4. Reindex back: swap source/dest
5. Delete temp: `DELETE /reindex_original`

## Why the `reindex_` prefix
Template patterns won't match, preventing automatic field analysis on temp data.
```

**Bad playbook** (tutorial, verbose, 80 lines):
```markdown
# Elasticsearch Reindexing Guide

## What is Reindexing?
Reindexing is the process of copying documents from one index to another...
[60 more lines of explanation]
```

The model already knows what reindexing is. Tell it what's **specific to your project**.

## Sizing Guidelines

| Level | Target Size | Content Type |
|-------|-------------|-------------|
| Level 0 (CLAUDE.md) | 30-50 lines | Identity, hard rules, routing table |
| Level 1 (playbooks) | 10-40 lines each | Task-specific workflows |
| Level 2 (reference) | Any length | Lookup tables, schemas, scripts |

The total documentation can be as long as needed — the point is that only the relevant slice is loaded at any time.

## Common Pitfalls

1. **Routing table is too vague** — "For backend work, see playbook" is useless. Be specific: "For Elasticsearch reindexing, see playbook."
2. **Playbooks are tutorials** — Don't explain concepts. Document your project's specific conventions and commands.
3. **Level 0 creep** — Over time, people add "just one more thing" to CLAUDE.md. Audit quarterly.
4. **Orphaned playbooks** — If the routing table doesn't point to it, the model won't find it. Keep the routing table current.
