# Why Hierarchical Context Works Better

## The Attention Bottleneck

Transformer-based models (GPT, Claude, etc.) use self-attention to process context. Every token in the context window attends to every other token. When you load 1,500 lines of documentation but only 30 lines are relevant to the current task:

- The model must process all 1,500 lines
- Relevant instructions compete for attention weight with irrelevant ones
- Instruction-following accuracy degrades as context length grows

This isn't theoretical — it's been measured. Research on "lost in the middle" effects (Liu et al., 2023) shows that models perform worse on information placed in the middle of long contexts. Your critical rules buried on line 280 of a CLAUDE.md file are literally harder for the model to follow than the same rules at line 10 of a 30-line file.

## Context Window Overflow

Every AI model has a finite context window. The conversation history (your messages, model responses, tool calls, file contents) accumulates until it hits the limit. When it overflows:

1. The system compresses or summarizes earlier messages
2. Nuance, corrections, and implicit context are lost
3. The model may repeat mistakes it was already corrected on

Loading 1,500 lines of documentation on every conversation accelerates this. If 80% of that documentation is irrelevant to the current task, you're burning context budget on noise.

## The Pyramid Solution

The pyramid architecture solves this by matching documentation loading to task scope:

| Approach | Context Loaded | Relevance |
|----------|---------------|-----------|
| Flat CLAUDE.md | Everything, every time | ~10-20% relevant |
| Pyramid Level 0 only | 50 lines | ~80% relevant |
| Pyramid L0 + 1 playbook | 80-90 lines | ~90% relevant |
| Pyramid L0 + L1 + L2 | 100-150 lines | ~95% relevant |
| Skill (live check) | 0 pre-loaded lines | 100% relevant (fetched on demand) |

The model gets *more relevant* context while loading *less total* context.

## Why Skills Beat Reference Sheets

Static reference sheets (port tables, config values, service lists) have a staleness problem. The moment someone changes a port or restarts a service, the doc is wrong. Worse, the model *trusts* the doc and wastes turns acting on bad info.

Skills solve this by being executable. A `/media-server` skill that SSHes in and runs `docker ps` returns the *current* state — always fresh, zero maintenance. Reference material should be reserved for **gotcha notes**: non-obvious things you can't derive from the live system (e.g., "qBittorrent bans your IP after 5 failed logins — restart the container").

## Why Routing Tables Work

The key innovation is the routing table in Level 0. It works because:

1. **Task classification is easy** — The model can tell whether it's writing tests, deploying, or debugging from the user's first message
2. **File reads are cheap** — Reading a playbook file costs 1 tool call, much cheaper than the attention cost of pre-loading everything
3. **Self-directed learning** — The model decides what it needs, loading only relevant playbooks

## Why Not Just Use RAG?

Retrieval-Augmented Generation (embedding your docs and doing semantic search) is the automated version of this. It works, but has tradeoffs:

**RAG advantages:**
- No manual curation needed
- Scales to thousands of documents
- Handles fuzzy queries

**Manual pyramid advantages:**
- Higher precision — human curation beats semantic similarity for project-specific knowledge
- No infrastructure — just markdown files
- Transparent — you can read and audit what the model will see
- Works with any AI tool — not tied to a specific RAG implementation

For most individual developers and small teams, the manual pyramid is simpler and more effective. RAG becomes worth it when you have hundreds of documents that change frequently.

## Empirical Observations

From analyzing 146 Claude Code sessions:

- **22% of sessions** hit context window overflow, requiring continuation
- **Most overflows** happened in the two projects with the longest CLAUDE.md files
- **Repeated corrections** (user re-explaining the same thing) correlated with documentation length — more docs meant more things for the model to miss
- **The most productive sessions** were short, focused tasks where the model already knew what to do — suggesting that pre-loaded context quality matters more than quantity
