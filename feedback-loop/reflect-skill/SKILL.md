---
name: reflect
description: Evolve project documentation by reading sessions and thinking about what context would have helped. Three levels — quick fix, deep analysis, or architectural rethink.
argument-hint: "[1|2|3|undo|dry-run] [optional: project or focus area]"
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Reflect

Three levels of documentation evolution. Default is level 1.

Parse the arguments from: $ARGUMENTS

- `/reflect` or `/reflect 1` → Level 1
- `/reflect 2` or `/reflect 2 zeitgeist` → Level 2
- `/reflect 3` → Level 3
- `/reflect undo` → `cd MYCELIUM_DIR && git revert HEAD` (confirm with user first)
- `/reflect dry-run` or `/reflect 1 dry-run` → Preview mode: do all analysis, present proposed changes as a numbered list, only apply after user confirms.

---

## Before ANYTHING Else — Git Checkpoint

**All levels.** Before editing any file:

```bash
cd MYCELIUM_DIR && git add -A && git commit -m "pre-reflect: checkpoint" --allow-empty
```

Tell the user: "Checkpoint saved. Undo with `/reflect undo`."

---

## Step 0 — Analyze the Current Session (all levels)

The current conversation is invisible to session history. **Always do this step first.**

Read back through your own conversation and ask:

1. **What did I not know at the start that I had to discover?**
2. **Where did the user correct my approach?** — Not just "no" — also redirections, abandoned paths.
3. **What took many turns that could have taken fewer?**
4. **What did the user have to repeat from a previous session?**

For each finding, note the specific knowledge gap and which doc file should contain it.

**These findings are your highest-quality input** — treat them with more weight than history, because you have full context.

---

## Reading Sessions

Use the read-session helper: `python3 MYCELIUM_DIR/feedback-loop/read-session.py SESSION_FILE --long`

Session history is at `~/.claude/session-history.jsonl`. Each record has: `timestamp`, `project`, `user_messages`, `tool_calls`, `reviewed`, `session_file`.

When reading a session, think about it as a whole story:
- What was the user trying to accomplish?
- Where did the session get stuck or go sideways?
- What context at the start would have made the whole thing smoother?
- What's generalizable vs. one-off?

---

## Level 1 — What Did I Just Learn? (default)

**Question:** "What did I learn in recent sessions that should be written down?"
**Scope:** Current conversation + 3-5 recent unreviewed sessions.
**Changes:** Edits to existing files only. No structural changes.

### Steps

1. Do Step 0 (analyze current session).
2. List unreviewed sessions from `session-history.jsonl`. Pick 3-5 with meaningful activity.
3. Read each conversation. For each: what knowledge was missing? What would have made it shorter?
4. For each gap, edit the relevant doc file. Only changes you're confident will help future sessions.
5. Finishing Steps.

---

## Level 2 — Are We Documenting the Right Things?

**Question:** "Are the playbooks organized around the actual work?"
**Scope:** Full session history for a project. Rethink structure.
**Changes:** Can restructure — create, merge, split, delete playbooks, rewrite routing tables.

### Steps

1. Do Step 0 (analyze current session).
2. Get session history overview (by project, counts, unreviewed).
3. For the target project (from arguments, or most unreviewed), read 10-15 sessions thoroughly.
4. Step back and think about the big picture:
   - What are the actual top 5 task types? (From sessions, not assumptions.)
   - Does each common task type have a playbook? Any playbooks for tasks that never happen?
   - What knowledge keeps being rediscovered?
   - Is CLAUDE.local.md over 50 lines? What can move to playbooks?
   - Does the routing table match reality?
5. Think about the ideal state. Restructure toward it.
6. Finishing Steps.

---

## Level 3 — Is This System Actually Working?

**Question:** "Is mycelium itself making sessions better?"
**Scope:** The framework — hook, /reflect, tooling, this SKILL.md, everything.
**Changes:** Can modify anything in MYCELIUM_DIR.

### Steps

1. Git checkpoint (already done above).
2. Read 15-20 sessions across projects. Read `feedback-log.md` for past reflect changes.
3. **Evaluate whether the system is helping:**
   - Do sessions get shorter/smoother over time for the same task types?
   - Are there tasks that keep going poorly despite having playbooks?
   - Are there sessions where the AI had good docs but ignored them?
4. **Question the design.** Is the architecture right? Consider:
   - Is the hook capturing what's needed? Too much? Too little?
   - Does the pyramid structure fit each project?
   - Does /reflect itself have flaws?
   - Is there unnecessary complexity that should be removed?
   - Is there a missing capability that should be built?
5. **Think about efficiency holistically.** The goal is "AI sessions that accomplish more with less friction":
   - Is maintenance time justified by session improvement?
   - Is /reflect making changes that actually matter, or churning?
   - What's the highest-leverage change right now?
6. Make changes. Document reasoning in `feedback-log.md`.
7. Commit: `cd MYCELIUM_DIR && git add -A && git commit -m "reflect-3: [description]"`

---

## Finishing Steps (all levels)

### Mark Sessions Reviewed

Update `session-history.jsonl` — set `reviewed: true` for each session ID you actually read. Also mark any zero-message sessions as reviewed (they're noise).

### Log What Changed

Append to `MYCELIUM_DIR/feedback-log.md`. Keep entries **compact** (3-5 lines max) — git commits have the detail:

```
## YYYY-MM-DD — /reflect level N
Sessions: N reviewed. Changes: [file1] (what), [file2] (what). Key finding: [one sentence].
```

If the log exceeds ~100 lines, archive older entries to `feedback-log-archive.md`.

---

## When to Reflect

Don't over-maintain. Diminishing returns set in fast.

- **Level 1**: Weekly, or after a session with obvious friction. Skip if <3 unreviewed sessions.
- **Level 2**: Monthly, or when a project's task types have shifted. One project at a time.
- **Level 3**: Quarterly, or when the system feels like it's not helping.

If you just ran a reflect and there are <5 unreviewed sessions, stop. The system is fine.

---

## Rules

- **Level 1**: Only edit existing files. No structural changes.
- **Level 2**: Can restructure. Explain why in the feedback log.
- **Level 3**: Can change anything. Document reasoning thoroughly.
- All levels: CLAUDE.local.md stays under 50 lines. Never edit CLAUDE.md (team-owned).
- All levels: Update the routing table when creating/deleting playbooks.
- All levels: Git checkpoint FIRST. No exceptions.
- **Core question for every change: "What would the AI have needed to know at the start of that session to make it go better?"** If you can't answer that concretely, don't make the change.
- **Cross-project memory principle**: CLAUDE.local.md is visible from all sessions in that directory tree. Memory files are only visible in their own project. When a fact is needed across projects (VPN, credentials, shared services), keep a minimal version in CLAUDE.local.md and a detailed version in one project's memory. Never assume other projects can read another project's memory files.
