# Reference: Team Context

## How Work Flows

Jacob receives direction from senior/lead engineers and implements. Claude is the execution partner.

Typical flow:
1. Boss or tech lead (Ian, Justin, Austin) gives direction via Jira comment, email, or Slack
2. Jacob pastes the direction into Claude Code
3. Claude brainstorms approach → Jacob approves → Claude implements
4. Jacob asks Claude to create PR, sometimes add Jira comment

## Team Members (referenced in conversations)

| Person | Role (inferred) | Context |
|--------|----------------|---------|
| Boss (unnamed) | Engineering lead | Gives ticket direction, reviews architecture decisions |
| Ian Canida | Senior engineer | Provides technical guidance on implementation |
| Justin | Engineer | Reviews PRs, provides code feedback |
| Austin | Engineer | Creates PRs that Jacob reviews |

## PR Review Pattern

- Jacob reviews others' PRs by asking Claude: "should I approve this?"
- Claude analyzes the PR and gives recommendation
- Jacob makes the final call

## Jira Workflow

- Project key: `DEV-XXX`
- Atlassian instance: `activecomply.atlassian.net`
- Jacob reads tickets, brainstorms with Claude, implements, then comments back on the ticket
- Boss sometimes adds context via Jira comments with specific technical direction
