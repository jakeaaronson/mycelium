# Playbook: Git & PR Workflow

## Branch Naming

```
DEV-{ticket_number}-{kebab-case-description}
```

Example: `DEV-623-linkedin-org-data-ingestion`

## The Full Cycle

1. **Create branch from `development`** (never from `main`):
   ```bash
   git checkout development && git pull
   git checkout -b DEV-XXX-description
   ```
2. **Make changes** — build and test before committing
3. **Commit** (only when user says "commit"):
   ```bash
   git add .  # Include ALL files unless told otherwise
   git commit  # Conventional format: feat:/fix:/refactor:/chore:
   ```
4. **Push and create PR**:
   ```bash
   git push -u origin DEV-XXX-description
   gh pr create --base development --title "DEV-XXX: description"
   ```
5. **Post to Jira** — User often asks "add a comment to the Jira ticket" after PR creation

## Common Mistakes

- Creating PR against `main` → Always target `development`
- Wrong branch naming → Must start with `DEV-{number}`
- Committing without being asked → Never auto-commit
- Not merging `development` into feature branch before push → Check for conflicts first

## CI/CD

After push, check build status:
```bash
gh pr checks {PR_NUMBER}
gh run list --limit 3
```

If build fails: read errors, fix, push again. User will say "see whats wrong with the build and fix it."
