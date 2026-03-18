#!/usr/bin/env python3
"""
Universal adapter — generates tool-specific L0 instruction files from
a pyramid structure (CLAUDE.md + docs/playbooks/ + docs/reference/).

Usage:
  python3 generate.py ~/my-project --tool claude-code
  python3 generate.py ~/my-project --tool codex
  python3 generate.py ~/my-project --tool all
  python3 generate.py ~/my-project --list   # Show what would be generated

Supported tools: claude-code, codex, gemini, cursor, cline, windsurf, goose, copilot
"""

import os
import re
import sys
import argparse

# ── Tool definitions ──

TOOLS = {
    "claude-code": {
        "name": "Claude Code",
        "file": "CLAUDE.md",
        "routing_format": "table",  # | Task | Read First |
        "routing_instruction": "Before starting work, check this table and read the relevant playbook.",
        "supports_hooks": True,
        "supports_skills": True,
        "notes": "",
    },
    "codex": {
        "name": "Codex (OpenAI)",
        "file": "AGENTS.md",
        "routing_format": "list",  # Codex walks the tree, so routing is simpler
        "routing_instruction": "Before starting work, read the relevant playbook from docs/playbooks/.",
        "supports_hooks": False,
        "supports_skills": True,
        "notes": "Codex auto-discovers AGENTS.md files in subdirectories. It walks up the directory tree.",
    },
    "gemini": {
        "name": "Gemini CLI",
        "file": "GEMINI.md",
        "routing_format": "table",
        "routing_instruction": "Before starting work, read the relevant playbook from docs/playbooks/.",
        "supports_hooks": False,
        "supports_skills": False,
        "notes": "Also supports AGENT.md as an alternative filename.",
    },
    "cursor": {
        "name": "Cursor",
        "file": ".cursor/rules/project.md",
        "routing_format": "list",
        "routing_instruction": "Before starting work, read the relevant playbook from docs/playbooks/.",
        "supports_hooks": False,
        "supports_skills": False,
        "notes": "Cursor uses .cursor/rules/ with MDC format. Legacy: .cursorrules",
    },
    "cline": {
        "name": "Cline",
        "file": ".clinerules/00-project.md",
        "routing_format": "list",
        "routing_instruction": "Before starting work, read the relevant playbook from docs/playbooks/.",
        "supports_hooks": True,
        "supports_skills": False,
        "notes": "Cline supports numbered rule files in .clinerules/ directory and has hook triggers.",
    },
    "windsurf": {
        "name": "Windsurf",
        "file": ".windsurfrules",
        "routing_format": "compact",  # 6K char limit — must be terse
        "routing_instruction": "Read the relevant playbook from docs/playbooks/ before starting work.",
        "supports_hooks": False,
        "supports_skills": False,
        "notes": "WARNING: .windsurfrules has a 6,000 character limit per file, 12,000 total. Keep L0 very lean.",
    },
    "goose": {
        "name": "Goose",
        "file": ".goosehints",
        "routing_format": "list",
        "routing_instruction": "Before starting work, read the relevant playbook from docs/playbooks/.",
        "supports_hooks": False,
        "supports_skills": False,
        "notes": "Goose reads .goosehints from root and per-directory.",
    },
    "copilot": {
        "name": "GitHub Copilot",
        "file": ".github/copilot-instructions.md",
        "routing_format": "list",
        "routing_instruction": "Before starting work, read the relevant playbook from docs/playbooks/.",
        "supports_hooks": False,
        "supports_skills": False,
        "notes": "",
    },
}


def scan_pyramid(project_dir):
    """Scan a project directory for pyramid docs."""
    result = {"l0": None, "playbooks": [], "references": []}

    # Find L0 (any instruction file)
    for name in ["CLAUDE.md", "AGENTS.md", "GEMINI.md"]:
        path = os.path.join(project_dir, name)
        if os.path.exists(path):
            with open(path) as f:
                result["l0"] = {"file": name, "content": f.read()}
            break

    # Scan playbooks
    pb_dir = os.path.join(project_dir, "docs", "playbooks")
    if os.path.isdir(pb_dir):
        for fname in sorted(os.listdir(pb_dir)):
            if fname.endswith(".md"):
                result["playbooks"].append(fname)

    # Scan references
    ref_dir = os.path.join(project_dir, "docs", "reference")
    if os.path.isdir(ref_dir):
        for fname in sorted(os.listdir(ref_dir)):
            if fname.endswith(".md"):
                result["references"].append(fname)

    return result


def generate_routing_table(playbooks, fmt):
    """Generate a routing table in the tool's preferred format."""
    if not playbooks:
        return ""

    lines = []
    if fmt == "table":
        lines.append("| Task | Read First |")
        lines.append("|------|-----------|")
        for pb in playbooks:
            name = pb.replace(".md", "").replace("-", " ").title()
            lines.append(f"| {name} | `docs/playbooks/{pb}` |")
    elif fmt == "list":
        for pb in playbooks:
            name = pb.replace(".md", "").replace("-", " ").title()
            lines.append(f"- **{name}**: Read `docs/playbooks/{pb}` first")
    elif fmt == "compact":
        # Ultra-terse for Windsurf's 6K limit
        for pb in playbooks:
            name = pb.replace(".md", "").replace("-", " ").title()
            lines.append(f"- {name} → docs/playbooks/{pb}")
    return "\n".join(lines)


def generate_l0(project_dir, tool_key, pyramid):
    """Generate the L0 instruction file for a specific tool."""
    tool = TOOLS[tool_key]

    # Use existing L0 content as base, or create from scratch
    if pyramid["l0"]:
        content = pyramid["l0"]["content"]
        # Replace the routing table section if it exists
        # Otherwise append it
        routing = generate_routing_table(pyramid["playbooks"], tool["routing_format"])
        if "## Before You Start" in content or "## Before you start" in content:
            # Already has routing — user maintains it
            pass
        elif routing:
            content += f"\n## Before You Start\n\n{tool['routing_instruction']}\n\n{routing}\n"
    else:
        # No existing L0 — generate minimal one
        project_name = os.path.basename(os.path.abspath(project_dir))
        routing = generate_routing_table(pyramid["playbooks"], tool["routing_format"])
        content = f"# {project_name}\n\n"
        content += f"<!-- Generated by mycelium for {tool['name']} -->\n\n"
        content += f"## Before You Start\n\n{tool['routing_instruction']}\n\n{routing}\n"

    return content


def write_l0(project_dir, tool_key, content):
    """Write the L0 file for a tool."""
    tool = TOOLS[tool_key]
    filepath = os.path.join(project_dir, tool["file"])
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, "w") as f:
        f.write(content)
    return filepath


def generate_agents_md(project_dir, pyramid):
    """Generate a cross-tool AGENTS.md from the pyramid structure.
    AGENTS.md is the emerging standard read by Codex, Cursor, and Gemini."""
    project_name = os.path.basename(os.path.abspath(project_dir))

    lines = [f"# {project_name}", ""]
    lines.append("<!-- Auto-generated by mycelium. https://anticapitalist.software/ -->")
    lines.append("<!-- This AGENTS.md is the cross-tool entry point. Codex, Cursor, and Gemini CLI read it. -->")
    lines.append("")

    # Use existing L0 content as the base
    if pyramid["l0"]:
        # Strip any tool-specific headers/comments and use the content
        content = pyramid["l0"]["content"]
        # Remove the # header line (we already added our own)
        content = re.sub(r'^# .*\n', '', content, count=1)
        lines.append(content.strip())
    else:
        lines.append(f"*No instruction file found. Add a CLAUDE.md or AGENTS.md to get started.*")

    # Ensure routing table is present
    if pyramid["playbooks"]:
        routing = generate_routing_table(pyramid["playbooks"], "list")
        if "docs/playbooks/" not in "\n".join(lines):
            lines.append("")
            lines.append("## Task-Specific Documentation")
            lines.append("")
            lines.append("Before starting work, read the relevant playbook:")
            lines.append("")
            lines.append(routing)

    # Add reference index
    if pyramid["references"]:
        lines.append("")
        lines.append("## Reference Documentation")
        lines.append("")
        for ref in pyramid["references"]:
            name = ref.replace(".md", "").replace("-", " ").title()
            lines.append(f"- `docs/reference/{ref}` — {name}")

    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description="Generate tool-specific L0 instruction files")
    parser.add_argument("project_dir", help="Path to project directory")
    parser.add_argument("--tool", default="claude-code",
                       help="Tool to generate for: " + ", ".join(TOOLS.keys()) + ", all")
    parser.add_argument("--agents-md", action="store_true",
                       help="Also generate AGENTS.md (cross-tool standard)")
    parser.add_argument("--list", action="store_true", help="Show what would be generated")
    parser.add_argument("--dry-run", action="store_true", help="Show content without writing")
    args = parser.parse_args()

    project_dir = os.path.abspath(args.project_dir)
    if not os.path.isdir(project_dir):
        print(f"Not a directory: {project_dir}")
        sys.exit(1)

    pyramid = scan_pyramid(project_dir)

    if args.list:
        print(f"Project: {project_dir}")
        print(f"Existing L0: {pyramid['l0']['file'] if pyramid['l0'] else 'none'}")
        print(f"Playbooks: {len(pyramid['playbooks'])}")
        for pb in pyramid["playbooks"]:
            print(f"  - {pb}")
        print(f"References: {len(pyramid['references'])}")
        for ref in pyramid["references"]:
            print(f"  - {ref}")
        return

    tools = list(TOOLS.keys()) if args.tool == "all" else [args.tool]

    for tool_key in tools:
        if tool_key not in TOOLS:
            print(f"Unknown tool: {tool_key}")
            print(f"Available: {', '.join(TOOLS.keys())}")
            sys.exit(1)

        tool = TOOLS[tool_key]
        content = generate_l0(project_dir, tool_key, pyramid)

        if args.dry_run:
            print(f"\n{'='*50}")
            print(f"  {tool['name']} → {tool['file']}")
            if tool["notes"]:
                print(f"  Note: {tool['notes']}")
            print(f"{'='*50}\n")
            print(content)
        else:
            filepath = write_l0(project_dir, tool_key, content)
            lines = content.count("\n") + 1
            print(f"  {tool['name']:20s} → {tool['file']:40s} ({lines} lines)")
            if tool["notes"]:
                print(f"  {'':20s}   Note: {tool['notes']}")

    # Generate AGENTS.md if requested or if generating for 'all'
    if args.agents_md or args.tool == "all":
        agents_content = generate_agents_md(project_dir, pyramid)
        agents_path = os.path.join(project_dir, "AGENTS.md")
        # Don't overwrite if codex already wrote it
        if not os.path.exists(agents_path) or args.tool != "codex":
            if args.dry_run:
                print(f"\n{'='*50}")
                print(f"  Cross-tool standard → AGENTS.md")
                print(f"  Note: Read by Codex, Cursor, and Gemini CLI (40K+ repos use this)")
                print(f"{'='*50}\n")
                print(agents_content)
            else:
                with open(agents_path, "w") as f:
                    f.write(agents_content)
                lines = agents_content.count("\n") + 1
                print(f"  {'AGENTS.md (cross-tool)':20s} → {'AGENTS.md':40s} ({lines} lines)")


if __name__ == "__main__":
    main()
