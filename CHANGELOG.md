# Changelog

## 2026-03-31 . v0.2: measure what matters

The feedback loop can now prove whether it's working.

- **Signal detection rewrite** — SessionEnd hook detects 5 friction types: corrections, frustrations, reexplanations, repeated reads, retry loops. Computes a friction score per session. Sessions scoring 10+ get `needs_review: true`.
- **health-check.py** — Full report with weekly trends, per-project breakdown, signal types, and friction distribution. `--brief` mode for one-line summaries. `--backfill` to recompute scores for historical sessions.
- **Session search** — `read-session.py --search TERM` greps across all session files with context snippets. `--summary` shows project overview with friction counts.
- **Backfill archive** — Old backfilled sessions (from before the hook existed) are now archived to a separate file so they don't inflate counts or confuse `/reflect`.
- **README + feedback-loop docs** updated with real baseline numbers from 220+ sessions.

## 2026-03-30 . v0.1: initial release

Changes:
- fix: remove co-author from publish commits, use personal email
- changelog: v0.1: initial release — pyramid docs with skills and gotcha notes
- changelog: v0.1: initial release — pyramid docs with skills and gotcha notes


## 2026-03-30 . v0.1: initial release — pyramid docs with skills and gotcha notes

Changes:
- changelog: v0.1: initial release — pyramid docs with skills and gotcha notes


## 2026-03-30 . v0.1: initial release — pyramid docs with skills and gotcha notes

Changes:
- fix: force checkout in publish.sh to handle stripped untracked files
- pre-publish: skills + gotcha notes restructure, sanitize examples
- reflect-2: activecomply-api — LinkedIn data flow docs, Chrome→Chromium, memory cleanup
- pre-reflect: checkpoint
- reflect-2: deep restructure of home project memory system
- pre-reflect: checkpoint
- reflect-2: SSH hosts reference, home network Mac/GDrive, routing table restructure
- pre-reflect: checkpoint
- open-source readiness: sanitize examples, fix generic hook, auto-install, parameterize SKILL.md
- reflect-3: add cadence guidance, compact feedback log, --tail mode, fix hook
- pre-reflect: checkpoint
- reflect-1: fix inkman's brain IP, add agent-house to network docs, update user context
- pre-reflect: checkpoint
- pre-reflect: checkpoint
- pre-reflect: checkpoint
- reflect-2: home directory — fix standup skill, add Linux admin reference, update hardware/standup docs
- pre-reflect: checkpoint
- reflect-3: simplify — unified git rollback, halved SKILL.md, cleaned dead files
- pre-reflect-3: checkpoint before architectural rethink
- cool new changes
- reflect-3: improve correction detection, sync enrich-backfill, add read-session helper
- pre-reflect-3: checkpoint before architectural rethink
- reflect-3: fix retry_loops false positives, add session dedup
- pre-reflect-3: checkpoint before architectural rethink
- reflect-3: target CLAUDE.local.md instead of CLAUDE.md
- reflect-3: fix false positive corrections, add skill text filtering, increase hook timeout
- pre-reflect-3: checkpoint before architectural rethink
- exclude .pyramid-backup and backup-* from project scanning
- setup finds projects from session history and git repos, not just instruction files
- reflect-3: Fix hook crash, rewrite signal detection, rebalance scoring
