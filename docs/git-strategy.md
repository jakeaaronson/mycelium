# Git Strategy

Mycelium uses a **local-first, publish-when-ready** git strategy. Your local repo tracks everything. Public repos only see clean, curated commits with private data stripped.

## The Three Tiers of Files

```
┌──────────────────────────────────────────────────────┐
│  NEVER TRACKED  (.gitignore)                         │
│  *.pyc, __pycache__, *.log                           │
│  Temporary, generated, cache. Nobody needs these.    │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│  LOCAL ONLY  (.publishignore)                        │
│  backup-*/, docs/research/, proposals/,              │
│  snapshots/, feedback-log.md, session-history.jsonl   │
│                                                      │
│  Tracked in your local git. Full history preserved.  │
│  Stripped before pushing to public repos.             │
│  Contains: real project data, team names, ticket     │
│  numbers, session analysis, credential paths.        │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│  PUBLIC  (everything else)                           │
│  The framework, templates, examples, scripts,        │
│  adapters, viewer, docs, feedback loop code.         │
│                                                      │
│  Published to GitHub and Forgejo.                    │
│  Clean, squashed commits. No personal data.          │
└──────────────────────────────────────────────────────┘
```

## Day to Day Workflow

Work normally. Commit whenever you want. Messy is fine.

```bash
# hack hack hack
git add -A && git commit -m "wip: trying new playbook structure"

# more hacking
git add -A && git commit -m "fix: validator was missing nargs"

# brainstorm session with Claude
git add -A && git commit -m "research: tool compatibility matrix"
```

Your local repo accumulates all of this. Nothing leaves your machine until you publish.

## Publishing

When you're ready to share your changes:

```bash
./publish.sh "v0.2: added Cursor adapter"
```

What happens:
1. Commits any uncommitted changes
2. Creates a temporary branch
3. Strips all files listed in `.publishignore` (backups, research, session data)
4. Squashes everything into one clean commit
5. Pushes to all configured remotes (GitHub, Forgejo)
6. Returns to your local branch (untouched)
7. Tags the local commit
8. Writes a CHANGELOG.md entry

The public repos only ever see clean `publish: ...` commits. Your local repo keeps the full messy history.

```
LOCAL (your machine)                PUBLIC (GitHub/Forgejo)

  wip: trying stuff                   publish: v0.1 initial release
  fix: typo                           publish: v0.2 added Cursor adapter
  wip: more experiments               publish: v0.3 improved /reflect
  research: mined 50 sessions
  fix: hook was broken
  local: updated backups
    |
    └──> publish.sh squashes ──>
```

## Setting Up Remotes

```bash
cd ~/mycelium

# GitHub
git remote add github git@github.com:YOUR_USERNAME/mycelium.git

# Forgejo (self-hosted or public instance)
git remote add forgejo git@forgejo.example.com:YOUR_USERNAME/mycelium.git

# Verify
git remote -v
```

publish.sh pushes to ALL configured remotes automatically.

## Dry Run

Always preview first:

```bash
./publish.sh --dry-run "v0.2: new feature"
```

Shows:
- How many files are local vs public vs stripped
- Which files would be published
- What the changelog entry would say
- Which remotes would receive the push

## What .publishignore Strips

| Pattern | What it contains | Why it's private |
|---------|-----------------|-----------------|
| `backup-*` | Original CLAUDE.md files | Contains work-specific code conventions |
| `docs/research/` | Conversation mining results | References real Jira tickets, team members, infrastructure |
| `proposals/` | /reflect output | Contains session-specific analysis |
| `snapshots/` | Point-in-time doc copies | Contains personal project docs |
| `feedback-log.md` | Record of /reflect changes | References specific sessions |
| `session-history.jsonl` | Session metadata | Contains project paths, signal data |
| `.publishignore` | This exclusion list | Not useful to public consumers |

## Tagging

publish.sh creates a local git tag for each publish. Tags are not pushed to remotes (they're for your local reference).

```bash
# See all publish points
git tag

# See what changed in a specific publish
git show v0.1-initial-release
```

## CHANGELOG.md

Each publish appends to CHANGELOG.md with:
- Date
- Publish message
- List of individual commits that were squashed

This preserves the detailed history even though the public repo only sees squashed commits.

## Recovering

If something goes wrong during publish:

```bash
# publish.sh never modifies your main branch
# It creates a temporary branch, does the work, then deletes it
# Your local branch is always safe

# If the temporary branch gets stuck:
git checkout main
git branch -D publish-staging-*

# If you need to see what was pushed:
git log --all --oneline
```

## Adding a New Private File

If you create a new file that should stay local:

1. Add the pattern to `.publishignore`
2. Commit normally (git tracks it locally)
3. publish.sh will strip it automatically

## Removing a File from Public

If you accidentally published something private:

1. Add it to `.publishignore`
2. Run `./publish.sh "remove private file X"`
3. The next publish will exclude it
4. Note: the file still exists in the public repo's git history. For truly sensitive data, you'd need to rewrite history on the remote.
