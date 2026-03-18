# Tool Adapters

The pyramid architecture is tool-agnostic. These adapters generate the right Level 0 instruction file for each AI coding tool.

## Supported Tools

| Tool | L0 File | Reads Playbooks? | Has Hooks? | Adapter |
|------|---------|------------------|-----------|---------|
| Claude Code | `CLAUDE.md` | Yes (via routing table) | Yes (SessionEnd) | `claude-code.sh` |
| Codex (OpenAI) | `AGENTS.md` | Yes (walks directory tree) | No | `codex.sh` |
| Gemini CLI | `GEMINI.md` | Yes (hierarchical) | No | `gemini.sh` |
| Cursor | `.cursor/rules/` | Yes (glob-scoped) | No | `cursor.sh` |
| Cline | `.clinerules/` | Yes (numbered files) | Yes (TaskStart) | `cline.sh` |
| Windsurf | `.windsurfrules` | Limited (6K char cap) | No | `windsurf.sh` |
| Goose | `.goosehints` | Yes (per-directory) | No | `goose.sh` |
| GitHub Copilot | `.github/copilot-instructions.md` | Limited | No | `copilot.sh` |

## How Adapters Work

Each adapter reads your pyramid structure (`CLAUDE.md` + `docs/playbooks/` + `docs/reference/`) and generates the equivalent instruction file for its tool. The playbooks and references stay as-is — they're just markdown files that any tool can read.

The only thing that changes per tool is:
1. **The Level 0 filename** (CLAUDE.md vs AGENTS.md vs GEMINI.md etc.)
2. **The routing table syntax** (how you tell the tool to read a playbook)
3. **Hook installation** (if the tool supports hooks)

## Usage

```bash
# Generate for a specific tool
./adapters/claude-code.sh ~/my-project
./adapters/codex.sh ~/my-project
./adapters/gemini.sh ~/my-project

# Generate for ALL tools at once (multi-tool projects)
./adapters/all.sh ~/my-project
```

## Multi-Tool Projects

Some teams use multiple tools (e.g., Cursor for IDE + Claude Code for CLI). Run multiple adapters — they don't conflict since each writes a different file:

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
