#!/usr/bin/env python3
"""
Builds viewer.html by reading all markdown files from the pyramid structure
and embedding them into a self-contained HTML file.

Usage: python3 build-viewer.py
"""

import os
import json
import html

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
EXAMPLES_DIR = os.path.join(SCRIPT_DIR, "examples")
DOCS_DIR = os.path.join(SCRIPT_DIR, "docs")

# ── Auto-scan registry: discovers projects and docs from filesystem ──

def scan_projects():
    """Auto-discover projects and their pyramid docs from examples/ directory."""
    projects = {
        "_framework": {
            "name": "Framework",
            "docs": [
                {"id": "home", "title": "Overview", "level": None, "path": None},
                {"id": "readme", "title": "README.md", "level": None, "file": os.path.join(SCRIPT_DIR, "README.md")},
            ]
        }
    }

    # Add framework docs from docs/ (excluding research/)
    for fname in sorted(os.listdir(DOCS_DIR)):
        if fname.endswith(".md"):
            fid = fname.replace(".md", "").replace("-", "_")
            title = fname.replace(".md", "").replace("-", " ").title()
            projects["_framework"]["docs"].append({
                "id": fid, "title": title, "level": None,
                "file": os.path.join(DOCS_DIR, fname)
            })

    # Scan example projects
    if not os.path.isdir(EXAMPLES_DIR):
        return projects

    for project_name in sorted(os.listdir(EXAMPLES_DIR)):
        project_dir = os.path.join(EXAMPLES_DIR, project_name)
        if not os.path.isdir(project_dir):
            continue

        # Generate short prefix from project name
        prefix = "".join(w[0] for w in project_name.split("-")[:2]) if "-" in project_name else project_name[:2]
        display_name = project_name.replace("-", " ").title()
        docs = []

        # L0: CLAUDE.md
        claude_md = os.path.join(project_dir, "CLAUDE.md")
        if os.path.exists(claude_md):
            docs.append({
                "id": f"{prefix}-claude", "title": "CLAUDE.md",
                "level": 0, "file": "CLAUDE.md"
            })

        # L1: Playbooks
        pb_dir = os.path.join(project_dir, "docs", "playbooks")
        if os.path.isdir(pb_dir):
            for fname in sorted(os.listdir(pb_dir)):
                if fname.endswith(".md"):
                    stem = fname.replace(".md", "")
                    title = stem.replace("-", " ").title()
                    docs.append({
                        "id": f"{prefix}-{stem}", "title": title,
                        "level": 1, "file": f"docs/playbooks/{fname}"
                    })

        # L2: Reference
        ref_dir = os.path.join(project_dir, "docs", "reference")
        if os.path.isdir(ref_dir):
            for fname in sorted(os.listdir(ref_dir)):
                if fname.endswith(".md"):
                    stem = fname.replace(".md", "")
                    title = stem.replace("-", " ").title()
                    docs.append({
                        "id": f"{prefix}-ref-{stem}", "title": title,
                        "level": 2, "file": f"docs/reference/{fname}"
                    })

        projects[project_name] = {
            "name": display_name,
            "prefix": prefix,
            "docs": docs
        }

    return projects


PROJECTS = scan_projects()


def read_file(path):
    try:
        with open(path, "r") as f:
            return f.read()
    except FileNotFoundError:
        return f"*File not found: {path}*"


def load_content():
    """Read all markdown files and return as {id: content} dict."""
    content = {}
    for project_key, project in PROJECTS.items():
        base = os.path.join(EXAMPLES_DIR, project_key) if project_key != "_framework" else None
        for doc in project.get("docs", []):
            if doc.get("file"):
                if project_key == "_framework":
                    path = doc["file"]
                else:
                    path = os.path.join(base, doc["file"])
                content[doc["id"]] = read_file(path)
    return content


def build_docs_json():
    """Build the DOCS registry as a JSON string for the HTML."""
    out = {}
    for key, proj in PROJECTS.items():
        out[key] = {
            "name": proj["name"],
            "docs": [
                {"id": d["id"], "title": d["title"], "level": d["level"],
                 "path": d.get("file")}
                for d in proj["docs"]
            ]
        }
    return json.dumps(out, indent=2)


def build_content_json(content):
    """Build the CONTENT dict as a JSON string for the HTML."""
    return json.dumps(content, indent=2)


def scan_snapshots():
    """Scan snapshots/ and backup-*/ directories for restore points."""
    snapshots = []
    snap_dir = os.path.join(SCRIPT_DIR, "snapshots")
    if os.path.isdir(snap_dir):
        for name in sorted(os.listdir(snap_dir), reverse=True):
            path = os.path.join(snap_dir, name)
            if not os.path.isdir(path):
                continue
            meta_path = os.path.join(path, "meta.json")
            meta = {}
            if os.path.exists(meta_path):
                try:
                    with open(meta_path) as f:
                        meta = json.load(f)
                except:
                    pass
            # Collect files and their contents for diff view
            file_count = 0
            file_list = []
            for root, dirs, files in os.walk(path):
                for fname in files:
                    if not fname.endswith(".md"):
                        continue
                    file_count += 1
                    fpath = os.path.join(root, fname)
                    rel = os.path.relpath(fpath, path)
                    try:
                        with open(fpath) as f:
                            content = f.read()
                        file_list.append({"path": rel, "lines": content.count("\n") + 1})
                    except:
                        file_list.append({"path": rel, "lines": 0})

            projects = [d for d in os.listdir(path)
                       if os.path.isdir(os.path.join(path, d)) and d != "_framework"]
            snapshots.append({
                "id": name,
                "type": "reflect",
                "timestamp": meta.get("timestamp", name),
                "level": meta.get("level", "?"),
                "args": meta.get("args", ""),
                "files": file_count,
                "file_list": file_list,
                "projects": projects,
                "path": path,
            })

    # Also scan backup-*/ directories
    for name in sorted(os.listdir(SCRIPT_DIR), reverse=True):
        if not name.startswith("backup-"):
            continue
        path = os.path.join(SCRIPT_DIR, name)
        if not os.path.isdir(path):
            continue
        # Read meta if exists
        meta = {}
        meta_path = os.path.join(path, "meta.json")
        if os.path.exists(meta_path):
            try:
                with open(meta_path) as f:
                    meta = json.load(f)
            except:
                pass
        file_count = 0
        file_list = []
        for root, dirs, files in os.walk(path):
            for fname in files:
                if not fname.endswith((".md", ".json")):
                    continue
                file_count += 1
                fpath = os.path.join(root, fname)
                rel = os.path.relpath(fpath, path)
                try:
                    lines = sum(1 for _ in open(fpath))
                except:
                    lines = 0
                file_list.append({"path": rel, "lines": lines})
        snapshots.append({
            "id": name,
            "type": "backup",
            "timestamp": meta.get("timestamp", name.replace("backup-", "")),
            "level": "full",
            "args": meta.get("args", "Original pre-pyramid CLAUDE.md files"),
            "files": file_count,
            "file_list": file_list,
            "projects": [f.replace("_CLAUDE.md", "")
                        for f in os.listdir(os.path.join(path, "claude-md-files"))
                        if f.endswith(".md")] if os.path.isdir(os.path.join(path, "claude-md-files")) else [],
            "path": path,
        })

    return snapshots


def build_snapshots_json():
    return json.dumps(scan_snapshots(), indent=2)


def generate_html(docs_json, content_json):
    """Load HTML template and inject data."""
    snapshots_json = build_snapshots_json()
    template_path = os.path.join(SCRIPT_DIR, "templates", "viewer.html")
    if os.path.exists(template_path):
        with open(template_path) as f:
            template = f.read()
        return (template
                .replace("/* __DOCS_JSON__ */", docs_json)
                .replace("/* __CONTENT_JSON__ */", content_json)
                .replace("/* __SNAPSHOTS_JSON__ */", snapshots_json))

    print(f"ERROR: Template not found at {template_path}")
    print("Run from the mycelium directory.")
    sys.exit(1)


def main():
    content = load_content()
    docs_json = build_docs_json()
    content_json = build_content_json(content)
    html = generate_html(docs_json, content_json)
    out_path = os.path.join(SCRIPT_DIR, "viewer.html")
    with open(out_path, "w") as f:
        f.write(html)
    doc_count = len([k for k in content if content[k]])
    total_lines = sum(c.count('\n') + 1 for c in content.values() if c)
    print(f"Built viewer.html — {doc_count} documents, {total_lines} total lines embedded")

    # Also build per-project viewers
    project_builder = os.path.join(SCRIPT_DIR, "build-project-viewer.py")
    if os.path.exists(project_builder):
        import subprocess
        subprocess.run([sys.executable, project_builder], cwd=SCRIPT_DIR, capture_output=False)


if __name__ == "__main__":
    import sys
    main()
