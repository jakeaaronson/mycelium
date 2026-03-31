#!/usr/bin/env python3
"""
Pyramid documentation validator. Checks for common problems:
- CLAUDE.md over 50 lines
- Routing table points to missing playbooks
- Playbooks over 50 lines
- Orphaned references nobody points to
- Missing quality checklist items

Usage:
  python3 validate.py ~/my-project          # Validate one project
  python3 validate.py                       # Validate all examples
  python3 validate.py --fix                 # Show fix suggestions
"""

import os
import re
import sys
import argparse

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# ── Colors ──
R = "\033[0;31m"
Y = "\033[1;33m"
G = "\033[0;32m"
DIM = "\033[2m"
B = "\033[1m"
NC = "\033[0m"


def find_l0(project_dir):
    """Find the L0 instruction file."""
    for name in ["CLAUDE.md", "AGENTS.md", "GEMINI.md", ".cursorrules", ".goosehints", ".windsurfrules"]:
        path = os.path.join(project_dir, name)
        if os.path.exists(path):
            return name, path
    # Check nested
    for nested in [".cursor/rules/project.md", ".clinerules/00-project.md", ".github/copilot-instructions.md"]:
        path = os.path.join(project_dir, nested)
        if os.path.exists(path):
            return nested, path
    return None, None


def extract_routing_targets(content):
    """Extract playbook paths from routing table in L0 file."""
    targets = []
    # Match markdown table cells and list items containing docs/playbooks/
    for match in re.finditer(r'`(docs/playbooks/[^`]+)`', content):
        targets.append(match.group(1))
    # Also match non-backtick references
    for match in re.finditer(r'docs/playbooks/(\S+\.md)', content):
        full = f"docs/playbooks/{match.group(1)}"
        if full not in targets:
            targets.append(full)
    return targets


def extract_reference_targets(content):
    """Extract reference paths from a file's content."""
    targets = []
    for match in re.finditer(r'`(docs/reference/[^`]+)`', content):
        targets.append(match.group(1))
    for match in re.finditer(r'docs/reference/(\S+\.md)', content):
        full = f"docs/reference/{match.group(1)}"
        if full not in targets:
            targets.append(full)
    return targets


def validate_project(project_dir, show_fix=False):
    """Validate a project's pyramid structure. Returns (errors, warnings)."""
    errors = []
    warnings = []
    project_name = os.path.basename(os.path.abspath(project_dir))

    # ── Check L0 exists ──
    l0_name, l0_path = find_l0(project_dir)
    if not l0_path:
        errors.append(("no-l0", "No instruction file found (CLAUDE.md, AGENTS.md, etc.)", None))
        return errors, warnings

    with open(l0_path) as f:
        l0_content = f.read()
    l0_lines = l0_content.count("\n") + 1

    # ── Check L0 size ──
    if l0_lines > 60:
        errors.append(("l0-too-long", f"{l0_name} is {l0_lines} lines (target: ≤50)", l0_path))
    elif l0_lines > 50:
        warnings.append(("l0-borderline", f"{l0_name} is {l0_lines} lines (target: ≤50)", l0_path))

    # ── Check routing table exists ──
    has_routing = bool(re.search(r'before you start|routing|read first|playbook', l0_content, re.I))
    if not has_routing:
        warnings.append(("no-routing", f"{l0_name} has no routing table (look for 'Before You Start' section)", l0_path))

    # ── Check routing targets exist ──
    routing_targets = extract_routing_targets(l0_content)
    for target in routing_targets:
        target_path = os.path.join(project_dir, target)
        if not os.path.exists(target_path):
            errors.append(("missing-playbook", f"Routing table references {target} but file doesn't exist", l0_path))

    # ── Check playbooks ──
    pb_dir = os.path.join(project_dir, "docs", "playbooks")
    playbook_files = []
    if os.path.isdir(pb_dir):
        for fname in sorted(os.listdir(pb_dir)):
            if not fname.endswith(".md"):
                continue
            playbook_files.append(fname)
            pb_path = os.path.join(pb_dir, fname)
            with open(pb_path) as f:
                pb_content = f.read()
            pb_lines = pb_content.count("\n") + 1

            # Size check
            if pb_lines > 60:
                warnings.append(("playbook-long", f"docs/playbooks/{fname} is {pb_lines} lines (target: 20-40)", pb_path))

            # Has commands?
            has_commands = "```" in pb_content
            if not has_commands:
                warnings.append(("playbook-no-commands", f"docs/playbooks/{fname} has no code blocks — playbooks should have runnable commands", pb_path))

            # Has common mistakes section?
            has_mistakes = bool(re.search(r'common mistake|do not|don.t|anti.pattern', pb_content, re.I))
            if not has_mistakes:
                warnings.append(("playbook-no-mistakes", f"docs/playbooks/{fname} has no 'Common Mistakes' section", pb_path))

            # Referenced from routing table?
            pb_relative = f"docs/playbooks/{fname}"
            if routing_targets and pb_relative not in routing_targets:
                warnings.append(("playbook-orphan", f"docs/playbooks/{fname} exists but isn't in the routing table", pb_path))
    else:
        warnings.append(("no-playbooks-dir", "docs/playbooks/ directory doesn't exist", None))

    # ── Check references ──
    ref_dir = os.path.join(project_dir, "docs", "reference")
    ref_files = []
    all_ref_targets = set()

    # Collect all reference pointers from L0 + playbooks
    all_ref_targets.update(extract_reference_targets(l0_content))
    if os.path.isdir(pb_dir):
        for fname in playbook_files:
            with open(os.path.join(pb_dir, fname)) as f:
                all_ref_targets.update(extract_reference_targets(f.read()))

    if os.path.isdir(ref_dir):
        for fname in sorted(os.listdir(ref_dir)):
            if not fname.endswith(".md"):
                continue
            ref_files.append(fname)
            ref_path = os.path.join(ref_dir, fname)
            ref_relative = f"docs/reference/{fname}"

            # Orphan check
            if all_ref_targets and ref_relative not in all_ref_targets:
                warnings.append(("reference-orphan", f"docs/reference/{fname} isn't referenced from any playbook or L0", ref_path))

    # Check for missing reference targets
    for target in all_ref_targets:
        target_path = os.path.join(project_dir, target)
        if not os.path.exists(target_path):
            warnings.append(("missing-reference", f"Playbook references {target} but file doesn't exist", None))

    return errors, warnings


def print_results(project_name, errors, warnings, show_fix=False):
    """Print validation results."""
    total = len(errors) + len(warnings)

    if total == 0:
        print(f"\n  {G}✓{NC} {B}{project_name}{NC} — all checks passed")
        return

    print(f"\n  {B}{project_name}{NC}")

    for code, msg, path in errors:
        print(f"    {R}ERROR{NC}  {msg}")
        if show_fix:
            if code == "missing-playbook":
                print(f"    {DIM}  Fix: Create the file, or remove it from the routing table{NC}")
            elif code == "l0-too-long":
                print(f"    {DIM}  Fix: Move sections to playbooks. Only keep what's needed in >50% of sessions{NC}")
            elif code == "no-l0":
                print(f"    {DIM}  Fix: Run ./setup.sh or python3 adapters/generate.py <project> --tool <tool>{NC}")

    for code, msg, path in warnings:
        print(f"    {Y}WARN{NC}   {msg}")
        if show_fix:
            if code == "playbook-orphan":
                print(f"    {DIM}  Fix: Add a row to the routing table in your L0 file{NC}")
            elif code == "playbook-long":
                print(f"    {DIM}  Fix: Move detailed content to docs/reference/. Target 20-40 lines{NC}")
            elif code == "playbook-no-commands":
                print(f"    {DIM}  Fix: Add runnable commands. Playbooks should be actionable, not conceptual{NC}")
            elif code == "playbook-no-mistakes":
                print(f"    {DIM}  Fix: Add a 'Common Mistakes' section with anti-patterns from /reflect{NC}")
            elif code == "reference-orphan":
                print(f"    {DIM}  Fix: Add a pointer from a playbook, or delete if unused{NC}")
            elif code == "no-routing":
                print(f"    {DIM}  Fix: Add a '## Before You Start' table mapping tasks to playbooks{NC}")


def main():
    parser = argparse.ArgumentParser(description="Validate pyramid documentation structure")
    parser.add_argument("project_dir", nargs="*", help="Project(s) to validate (default: all examples)")
    parser.add_argument("--fix", action="store_true", help="Show fix suggestions")
    args = parser.parse_args()

    print(f"\n  {B}Pyramid Validator{NC}")
    print(f"  {'─' * 40}")

    total_errors = 0
    total_warnings = 0

    if args.project_dir:
        dirs = args.project_dir
    else:
        # Validate all examples + any local projects with pyramid structure
        dirs = []
        examples = os.path.join(SCRIPT_DIR, "examples")
        if os.path.isdir(examples):
            for name in sorted(os.listdir(examples)):
                path = os.path.join(examples, name)
                if os.path.isdir(path):
                    dirs.append(path)
        # Also check home dir for any projects with pyramid structure
        home = os.path.expanduser("~")
        for name in sorted(os.listdir(home)):
            path = os.path.join(home, name)
            if os.path.isdir(path) and not name.startswith(".") and name != "mycelium" and find_l0(path)[0]:
                dirs.append(path)

    for d in dirs:
        project_name = os.path.basename(os.path.abspath(d))
        errors, warnings = validate_project(d, args.fix)
        print_results(project_name, errors, warnings, args.fix)
        total_errors += len(errors)
        total_warnings += len(warnings)

    print(f"\n  {'─' * 40}")
    if total_errors == 0 and total_warnings == 0:
        print(f"  {G}All checks passed.{NC}\n")
    else:
        print(f"  {R if total_errors else Y}{total_errors} errors, {total_warnings} warnings{NC}\n")

    sys.exit(1 if total_errors > 0 else 0)


if __name__ == "__main__":
    main()
