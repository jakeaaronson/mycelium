# Tool Adapters

The pyramid architecture is tool-agnostic. The `generate.py` adapter creates the right instruction file for each AI coding tool from your existing pyramid structure.

## Supported Tools

| Tool | L0 File | Reads Playbooks? | Has Hooks? |
|------|---------|------------------|-----------|
| Claude Code | `CLAUDE.md` | Yes (via routing table) | Yes (SessionEnd) |
| Codex (OpenAI) | `AGENTS.md` | Yes (walks directory tree) | No |
| Gemini CLI | `GEMINI.md` | Yes (hierarchical) | No |
| Cursor | `.cursor/rules/` | Yes (glob-scoped) | No |
| Cline | `.clinerules/` | Yes (numbered files) | Yes (TaskStart) |
| Windsurf | `.windsurfrules` | Limited (6K char cap) | No |
| Goose | `.goosehints` | Yes (per-directory) | No |
| GitHub Copilot | `.github/copilot-instructions.md` | Limited | No |

## Usage

```bash
# Generate for a specific tool
python3 adapters/generate.py ~/my-project --tool claude-code
python3 adapters/generate.py ~/my-project --tool codex
python3 adapters/generate.py ~/my-project --tool gemini

# Generate for ALL tools at once (multi-tool projects)
python3 adapters/generate.py ~/my-project --tool all

# Preview what would be generated
python3 adapters/generate.py ~/my-project --list
```

## How It Works

The adapter reads your pyramid structure (`CLAUDE.md` + `docs/playbooks/` + `docs/reference/`) and generates the equivalent instruction file for the target tool. The playbooks and references stay as-is — they're just markdown files that any tool can read.

The only thing that changes per tool is:
1. **The L0 filename** (CLAUDE.md vs AGENTS.md vs GEMINI.md etc.)
2. **The routing table syntax** (how you tell the tool to read a playbook)
3. **Hook installation** (if the tool supports hooks)

## Multi-Tool Projects

Some teams use multiple tools (e.g., Cursor for IDE + Claude Code for CLI). Run the adapter for each tool — they don't conflict since each writes a different file:

```
my-project/
├── CLAUDE.md              # Claude Code reads this
├── AGENTS.md              # Codex reads this
├── GEMINI.md              # Gemini CLI reads this
├── .cursor/rules/         # Cursor reads this
├── docs/
│   ├── playbooks/         # ALL tools read these (via routing table)
│   └── reference/         # ALL tools read these (via playbook pointers)
```

The playbooks and references are the shared source of truth. The L0 files are just tool-specific entry points into the same pyramid.
