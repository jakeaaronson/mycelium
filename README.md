# Mycelium

**A self-improving memory and documentation system for AI coding agents.**
*Hierarchical memory for non-hierarchical organizations.*

Your AI assistant forgets everything between conversations. Mycelium fixes that, not by stuffing more into its context window, but by loading *only what's relevant* and getting smarter every session.

Works with Claude Code, Codex, Gemini CLI, Cursor, Cline, Windsurf, Goose, and GitHub Copilot.

Licensed under the [Anti-Capitalist Software License](https://anticapitalist.software/). Free for individuals, cooperatives, nonprofits, and educational institutions.

---

## The Problem

Context is everything. An AI model with the right 30 lines of context will outperform the same model with 500 lines of unfocused documentation. Research on transformer attention shows that irrelevant context actively degrades performance. The model doesn't just ignore the noise, it competes for the same attention budget as your actual instructions. More is not better. *Right* is better.

Every AI coding tool loads an instruction file on every conversation. These files grow. A 400-line instruction file means the model wastes attention on 370 lines that don't matter right now. Your corrections get lost between sessions. The model makes the same mistakes twice. In our testing, 41% of sessions hit context window limits. The model literally ran out of room to think because the documentation was taking up too much space.

## What Mycelium Does

**1. The Pyramid.** Replaces one bloated file with a layered structure:

```
         ┌──────────┐
         │  50 lines │  Always loaded. Identity + routing table.
         └─────┬─────┘
        ┌──────┴──────┐
        │  Playbooks   │  Loaded per task. "How to do X."
        └──────┬──────┘
   ┌───────────┴───────────┐
   │  Gotcha Notes + Skills │  Lean references + executable helpers.
   └───────────────────────┘
```

Instead of 400 lines every time, the model loads ~80 lines of exactly what it needs.

**Skills over reference sheets.** Procedural knowledge (checking server status, setting up a worker) belongs in executable skills that return *current* state, not static documents that go stale. Reference material should be trimmed to **gotcha notes** — only the non-obvious things you can't derive from reading the code or running a command.

**2. The Feedback Loop.** Every session teaches the system:

```
You work normally > session ends > hook detects what went wrong >
you run /reflect > docs improve > next session is better
```

The model corrected you? That correction becomes a playbook rule. You re-explained something? That knowledge gets documented. Context overflowed? The docs get trimmed. **The system composts its own mistakes into better documentation.**

**3. Tool Agnostic.** The playbooks are just markdown files. Any AI tool or human can read them. Only the "entry point" filename changes per tool. One command generates instruction files for all your tools at once.

## Quick Start

```bash
git clone https://github.com/jakeaaronson/mycelium.git
cd mycelium
./setup.sh
```

The wizard walks you through everything: finds your projects, analyzes your current docs, creates the structure, installs the feedback loop.

## How /reflect Works

Three levels of self-improvement:

```
/reflect          Fix docs from recent sessions. Quick, safe.
/reflect 2        Replay full history. Restructure playbooks.
/reflect 3        Rethink the framework itself. For contributors.
/reflect undo     Revert the last reflect via git.
/reflect dry-run  Preview changes before applying.
```

Every reflect creates a git checkpoint first. You can always go back.

## Why "Mycelium"?

Mycelium is the underground fungal network that connects trees in a forest. No central authority. Nutrients transfer to where they're needed. Dead matter decomposes into food for new growth. The network gets stronger as the forest grows.

This project works the same way:
- **No vendor lock-in.** Works with any AI tool.
- **Nutrients flow where needed.** Playbooks load only when relevant.
- **Dead matter becomes growth.** Failed sessions become better documentation.
- **Gets stronger over time.** The feedback loop means your docs evolve.

Like mycelium, it's invisible infrastructure. You don't see it working. You just notice that everything works better.

## Project Structure

```
mycelium/
├── setup.sh                    Start here
├── validate.py                 Check your docs for problems
├── viewer.html                 Browse the pyramid visually
│
├── examples/                   Real-world implementations (media-server, community-platform)
├── templates/                  Blank starting templates
├── adapters/                   Generate for Codex, Gemini, Cursor, etc.
├── feedback-loop/              SessionEnd hook + /reflect + health-check
└── docs/                       Theory, adaptation guide, research
```

### Prerequisites

- `python3` (for validate.py, adapters, feedback loop)
- `jq` (for the SessionEnd hook)
- `git` (for reflect checkpoints and undo)

## The Numbers

Built from mining 220+ real coding sessions across 10 projects:

| Metric | Before Mycelium | After |
|--------|----------------|-------|
| Instruction file size | 300-500 lines (always loaded) | ~50 lines + playbooks on demand |
| Clean sessions (zero friction) | ~30% | 39% and trending up |
| High friction sessions (score 30+) | ~35% | 23% and trending down |
| Documentation maintenance | Manual, sporadic | Automatic via /reflect |

The feedback loop now **measures its own effectiveness**. Each session gets a friction score based on detected corrections, frustrations, repeated reads, and retry loops. Run `health-check.py` to see the trend — if the score isn't going down, the docs aren't helping.

## Who This Is For

- **Individual developers** using AI coding assistants who are tired of re-explaining things
- **Small teams and cooperatives** who want shared, evolving documentation
- **Educators** teaching AI-assisted development
- **Open source maintainers** who want their repos to be AI-friendly

## Who This Is NOT For

Per the [Anti-Capitalist Software License v1.4](https://anticapitalist.software/):

- Not for organizations that extract profit from workers without shared ownership
- Not for law enforcement or military
- Not for surveillance or exploitation

If your organization has owners who aren't workers, or workers who aren't owners, this license doesn't apply to you.

## Related Work

- [AGENTS.md standard](https://agents.md/) . Cross-tool instruction file format (40K+ repos)
- [Anthropic's CLAUDE.md](https://docs.anthropic.com/en/docs/claude-code/memory) . The convention this builds on
- [Letta Code](https://www.letta.com/blog/letta-code) . Memory-first coding agent
- [ACE (Agentic Context Engineering)](https://github.com/ace-agent/ace) . Context engineering framework
- [Memory for AI Agents (The New Stack)](https://thenewstack.io/memory-for-ai-agents-a-new-paradigm-of-context-engineering/) . The paradigm shift
- [Hindsight](https://github.com/vectorize-io/hindsight) . Learning agent memory

## License

[Anti-Capitalist Software License v1.4](https://anticapitalist.software/) . See [LICENSE](LICENSE).
