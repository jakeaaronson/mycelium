---
name: reflect
description: Evolve pyramid documentation from session history. Three levels — quick fix, deep analysis, or architectural rethink.
argument-hint: "[1|2|3|undo|dry-run] [optional: project or focus area]"
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Reflect

Three levels of documentation evolution. Default is level 1.

Parse the arguments from: $ARGUMENTS

- `/reflect` or `/reflect 1` → Level 1
- `/reflect 2` or `/reflect 2 zeitgeist` → Level 2
- `/reflect 3` → Level 3
- `/reflect undo` → Restore from last snapshot (see Undo section)
- `/reflect dry-run` or `/reflect 1 dry-run` → Preview mode (any level)

**Dry-run mode:** If `dry-run` appears anywhere in the arguments, do ALL the analysis work (read sessions, identify gaps, find the files, write the exact changes) but **do NOT apply them**. Instead, present each proposed change as a numbered list with file path, current text, and proposed text. Then ask: "Apply all? Apply some? Cancel?" Only proceed if the user confirms. Dry-run still creates a snapshot (safety first).

---

## Before ANYTHING Else — Snapshot (Level 1 and 2 only)

**This runs before every Level 1 and Level 2 reflect. No exceptions.**

**Level 3 skips this step and uses git instead** (see Level 3 section).

Before editing any file, create a snapshot of everything you might touch:

```bash
SNAP_DIR="$HOME/mycelium/snapshots/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SNAP_DIR"

# Snapshot all pyramid docs across all projects
for project_dir in ~/activecomply-api ~/thezeitgeistexperiment ~/dashboard-app ~/survey-app ~/dev-agents; do
  if [ -f "$project_dir/CLAUDE.md" ]; then
    proj=$(basename "$project_dir")
    mkdir -p "$SNAP_DIR/$proj"
    cp "$project_dir/CLAUDE.md" "$SNAP_DIR/$proj/"
    [ -d "$project_dir/docs/playbooks" ] && cp -r "$project_dir/docs/playbooks" "$SNAP_DIR/$proj/"
    [ -d "$project_dir/docs/reference" ] && cp -r "$project_dir/docs/reference" "$SNAP_DIR/$proj/"
  fi
done

# Snapshot framework docs (for level 3)
mkdir -p "$SNAP_DIR/_framework"
cp ~/mycelium/README.md "$SNAP_DIR/_framework/" 2>/dev/null || true
cp ~/mycelium/feedback-loop/reflect-skill/SKILL.md "$SNAP_DIR/_framework/" 2>/dev/null || true
cp ~/mycelium/feedback-loop/session-end-log.sh "$SNAP_DIR/_framework/" 2>/dev/null || true

# Record metadata
echo "{\"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"level\": \"$LEVEL\", \"args\": \"$ARGUMENTS\"}" > "$SNAP_DIR/meta.json"

echo "Snapshot saved: $SNAP_DIR"
```

Tell the user: "Snapshot saved. If you want to undo this reflect, run `/reflect undo`."

---

## Level 1 — Quick Reflect (default)

**Scope:** Current conversation + any flagged sessions since last reflect.
**Time:** Fast. Apply obvious fixes, skip anything ambiguous.
**Changes:** Edits to existing playbooks and references only. No structural changes.

### Steps

1. Read `~/.claude/session-history.jsonl`, find entries with `needs_review: true` AND `reviewed: false`:

```bash
python3 -c "
import json, sys
sessions = [json.loads(l) for l in open('$HOME/.claude/session-history.jsonl')]
pending = [s for s in sessions if s.get('needs_review') and not s.get('reviewed')]
pending.sort(key=lambda s: s.get('score', 0), reverse=True)
for s in pending[:10]:
    sig = s.get('signals', {})
    print(f\"  [{s['score']:3d}] {s['project']:20s} corr={sig.get('corrections',0)} reexp={sig.get('reexplanations',0)} frust={sig.get('frustrations',0)} overflow={sig.get('overflows',0)} reads={sig.get('repeated_reads',0)}\")
print(f'\n  {len(pending)} total pending')
"
```

2. For the top 5 highest-scoring sessions, read the conversation and identify:
   - What knowledge was missing from the docs
   - What the user had to repeat or correct

3. For each gap, edit the relevant playbook or reference file directly. Only make changes you're confident about.

4. Mark reviewed sessions and log changes (see Finishing Steps below).

---

## Level 2 — Deep Analysis

**Scope:** Full session history replay. Rethink playbook organization and content.
**Time:** Slow. Read many sessions, look for patterns across sessions, not just individual signals.
**Changes:** Can restructure playbooks, create new ones, merge redundant ones, rewrite sections.

### Steps

1. Read ALL sessions from `~/.claude/session-history.jsonl` (not just flagged ones):

```bash
python3 -c "
import json
sessions = [json.loads(l) for l in open('$HOME/.claude/session-history.jsonl')]
by_project = {}
for s in sessions:
    p = s.get('project', 'unknown')
    by_project.setdefault(p, []).append(s)
for p, ss in sorted(by_project.items(), key=lambda x: -len(x[1])):
    flagged = sum(1 for s in ss if s.get('needs_review'))
    total_sig = sum(s.get('total_signals', 0) for s in ss)
    avg_score = sum(s.get('score', 0) for s in ss) / max(len(ss), 1)
    print(f'  {p:20s}  {len(ss):3d} sessions  {flagged:2d} flagged  {total_sig:3d} signals  avg={avg_score:.0f}')
"
```

2. For the project with the most signals (or the one specified in arguments), read 10-15 sessions — especially the highest-scoring ones. Extract conversations using:

```bash
python3 -c "
import json
for line in open('SESSION_FILE_PATH'):
    try:
        obj = json.loads(line)
        if obj.get('type') not in ('user', 'assistant'): continue
        content = obj.get('message', {}).get('content', '')
        if isinstance(content, str) and len(content) > 15 and not content.startswith('<'):
            print(f'[{obj[\"type\"]}] {content[:500]}')
            print()
        elif isinstance(content, list):
            for c in content:
                if isinstance(c, dict) and c.get('type') == 'text' and len(c.get('text','')) > 15:
                    print(f'[{obj[\"type\"]}] {c[\"text\"][:500]}')
                    print()
    except: pass
"
```

3. Look for **patterns**, not just individual gaps:
   - Are multiple playbooks covering overlapping territory? → Merge them
   - Is one playbook referenced by many sessions but missing key info? → Expand it
   - Are there task types that have no playbook but come up often? → Create one
   - Is CLAUDE.md over 50 lines? → Push content down to playbooks
   - Are reference sheets being loaded that could be simpler? → Trim them

4. Think about the **optimal layout** of the pyramid for this project:
   - What are the actual top 5 task types? (not what we assumed — what the data shows)
   - Does the routing table match reality?
   - Are the Level 0 hard rules still the right ones?

5. Restructure as needed. Create, merge, split, or delete playbooks. Rewrite the routing table if needed.

6. Finish with Finishing Steps below.

---

## Level 3 — Architectural Rethink

**Scope:** The framework itself. Question the pyramid structure, the signal detection, the feedback loop.
**Time:** Very slow. This is a contribution to the project, not just personal doc maintenance.
**Changes:** Can modify templates, build scripts, the hook, the /reflect skill itself, README, anything.
**Who:** Project maintainers and contributors only.

### IMPORTANT: Level 3 does NOT use the snapshot system.

Level 3 can modify the snapshot/undo system itself (this SKILL.md, the hook, the build scripts). Snapshotting code that you're about to rewrite creates a paradox — the old snapshot might not be restorable with the new undo code.

**Instead, Level 3 uses git:**

```bash
cd ~/mycelium
git add -A && git commit -m "pre-reflect-3: checkpoint before architectural rethink"
```

To undo a Level 3 reflect:
```bash
cd ~/mycelium
git diff HEAD~1   # See what changed
git revert HEAD   # Undo it
```

**Skip the "Before ANYTHING Else — Snapshot" step for Level 3. Use git instead.**

### Steps

1. **Git checkpoint first** (see above).

2. Do Level 2 analysis first — read session history, identify patterns.

3. Then step back and evaluate the **framework itself**:

   - **Is the 3-level pyramid the right structure?** Maybe some projects need 2 levels. Maybe some need 4. Look at which levels actually get used.

   - **Are the signal detection patterns right?** Read 20+ flagged sessions. Were they correctly flagged? Are there false positives (flagged but nothing was actually wrong)? Are there false negatives (real problems that weren't flagged)?

   - **Is the routing table concept working?** Does the model actually read the playbook before starting work? Or does it skip the routing table and just dive in?

   - **What's the optimal CLAUDE.md size?** We said 50 lines. Is that right? Could it be 30? Could it be 80? Look at which sessions had the fewest corrections and what their L0 size was.

   - **Is /reflect itself working?** Are the changes it makes actually improving things? Check the feedback-log.md — are signal scores declining over time?

4. Propose changes to the framework:
   - Template modifications → `templates/`
   - Build script improvements → `build-viewer.py`, `build-project-viewer.py`
   - Hook improvements → `feedback-loop/session-end-log.sh`
   - This skill itself → `feedback-loop/reflect-skill/SKILL.md`
   - README updates → `README.md`
   - New documentation → `docs/`

5. Write a detailed entry in `~/mycelium/feedback-log.md` explaining:
   - What data led to the conclusion
   - What was changed and why
   - What the expected impact is
   - How to measure if it worked

6. Commit the changes as a proper git commit (not a snapshot):
```bash
cd ~/mycelium
git add -A && git commit -m "reflect-3: [description of architectural change]"
```

---

## Finishing Steps (all levels)

### Mark Sessions Reviewed

```bash
python3 -c "
import json
lines = open('$HOME/.claude/session-history.jsonl').readlines()
reviewed_ids = set()  # Add the session IDs you actually read
updated = []
for line in lines:
    s = json.loads(line.strip())
    if s.get('session_id') in reviewed_ids:
        s['reviewed'] = True
    updated.append(json.dumps(s))
with open('$HOME/.claude/session-history.jsonl', 'w') as f:
    f.write('\n'.join(updated) + '\n')
print(f'Marked {len(reviewed_ids)} sessions as reviewed')
"
```

### Log What Changed

Append to `~/mycelium/feedback-log.md`:

```
## YYYY-MM-DD — /reflect level N

Sessions reviewed: N
Changes made:
- [file]: [what changed and why]

Signals resolved: N corrections, N re-explanations, N frustrations
```

### Rebuild Viewers (if docs changed)

```bash
python3 ~/mycelium/build-viewer.py
python3 ~/mycelium/build-project-viewer.py
```

## Undo

**`/reflect undo` restores Level 1 and Level 2 changes only** (project docs: CLAUDE.md, playbooks, references).

**It cannot undo Level 3 changes** (framework code). For Level 3, use `git revert HEAD` in the `~/mycelium` repo.

If the argument is `undo` (i.e. user ran `/reflect undo`), restore from the most recent snapshot:

```bash
# Find the latest snapshot
LATEST=$(ls -td ~/mycelium/snapshots/*/ 2>/dev/null | head -1)
if [ -z "$LATEST" ]; then
  echo "No snapshots found. Nothing to undo."
  exit 0
fi

echo "Latest snapshot: $LATEST"
echo "Created: $(cat "$LATEST/meta.json" 2>/dev/null || echo 'unknown')"
echo ""
```

Then show the user what will be restored:
```bash
echo "Files that will be restored:"
find "$LATEST" -name "*.md" -o -name "*.sh" | sed "s|$LATEST||" | sort
```

Ask the user to confirm. If they confirm:

```bash
# Restore each project's files
for proj_dir in "$LATEST"/*/; do
  proj=$(basename "$proj_dir")
  if [ "$proj" = "_framework" ]; then
    # Framework files go back to ~/mycelium/
    [ -f "$proj_dir/README.md" ] && cp "$proj_dir/README.md" ~/mycelium/
    [ -f "$proj_dir/SKILL.md" ] && cp "$proj_dir/SKILL.md" ~/mycelium/feedback-loop/reflect-skill/ && cp "$proj_dir/SKILL.md" ~/.claude/skills/reflect/
    [ -f "$proj_dir/session-end-log.sh" ] && cp "$proj_dir/session-end-log.sh" ~/mycelium/feedback-loop/ && cp "$proj_dir/session-end-log.sh" ~/.claude/hooks/
  else
    # Project files go back to ~/$project/
    TARGET="$HOME/$proj"
    [ -f "$proj_dir/CLAUDE.md" ] && cp "$proj_dir/CLAUDE.md" "$TARGET/"
    [ -d "$proj_dir/playbooks" ] && cp -r "$proj_dir/playbooks/"* "$TARGET/docs/playbooks/" 2>/dev/null || true
    [ -d "$proj_dir/reference" ] && cp -r "$proj_dir/reference/"* "$TARGET/docs/reference/" 2>/dev/null || true
  fi
done

echo "Restored from: $(basename $LATEST)"
```

After restoring, rebuild the viewers:
```bash
python3 ~/mycelium/build-viewer.py
python3 ~/mycelium/build-project-viewer.py
```

The snapshot directory is kept (not deleted) so you can undo the undo if needed. Old snapshots can be cleaned up manually from `~/mycelium/snapshots/`.

---

## Rules

- **Level 1**: Only edit existing files. No structural changes. Fast and safe.
- **Level 2**: Can restructure. But always explain why in the feedback log.
- **Level 3**: Can change anything. But must document the reasoning thoroughly.
- All levels: CLAUDE.md stays under 50 lines. Don't document what the model can find in code.
- All levels: Update the routing table when creating/deleting playbooks.
- All levels: Snapshot FIRST. Always. No exceptions.
