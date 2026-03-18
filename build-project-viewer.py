#!/usr/bin/env python3
"""
Builds a standalone viewer.html for a single project directory.
Scans for CLAUDE.md, docs/playbooks/*.md, docs/reference/*.md.

Usage: python3 build-project-viewer.py /path/to/project
"""

import os
import sys
import json

def find_docs(project_dir):
    """Scan project dir for pyramid documents."""
    docs = []
    content = {}

    # L0: CLAUDE.md
    claude_md = os.path.join(project_dir, "CLAUDE.md")
    if os.path.exists(claude_md):
        with open(claude_md) as f:
            content["l0-claude"] = f.read()
        docs.append({"id": "l0-claude", "title": "CLAUDE.md", "level": 0, "path": "CLAUDE.md"})

    # L1: Playbooks
    pb_dir = os.path.join(project_dir, "docs", "playbooks")
    if os.path.isdir(pb_dir):
        for fname in sorted(os.listdir(pb_dir)):
            if fname.endswith(".md"):
                fid = "l1-" + fname.replace(".md", "")
                path = os.path.join(pb_dir, fname)
                with open(path) as f:
                    content[fid] = f.read()
                title = fname.replace(".md", "").replace("-", " ").title()
                docs.append({"id": fid, "title": title, "level": 1, "path": f"docs/playbooks/{fname}"})

    # L2: Reference
    ref_dir = os.path.join(project_dir, "docs", "reference")
    if os.path.isdir(ref_dir):
        for fname in sorted(os.listdir(ref_dir)):
            if fname.endswith(".md"):
                fid = "l2-" + fname.replace(".md", "")
                path = os.path.join(ref_dir, fname)
                with open(path) as f:
                    content[fid] = f.read()
                title = fname.replace(".md", "").replace("-", " ").title()
                docs.append({"id": fid, "title": title, "level": 2, "path": f"docs/reference/{fname}"})

    return docs, content


def generate(project_dir):
    project_name = os.path.basename(os.path.abspath(project_dir))
    docs, content = find_docs(project_dir)

    if not docs:
        print(f"No pyramid docs found in {project_dir}")
        return

    docs_json = json.dumps({"project": {"name": project_name, "docs": docs}}, indent=2)
    content_json = json.dumps(content, indent=2)

    # Counts
    l0 = sum(content[d["id"]].count('\n')+1 for d in docs if d["level"] == 0 and d["id"] in content)
    l1 = sum(content[d["id"]].count('\n')+1 for d in docs if d["level"] == 1 and d["id"] in content)
    l2 = sum(content[d["id"]].count('\n')+1 for d in docs if d["level"] == 2 and d["id"] in content)
    l1c = sum(1 for d in docs if d["level"] == 1)
    l2c = sum(1 for d in docs if d["level"] == 2)

    html = f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{project_name} — Pyramid Docs</title>
<style>
  :root {{ --bg:#0a0a0b; --s:#141416; --s2:#1c1c20; --b:#27272a; --t:#e4e4e7; --tm:#a1a1aa; --td:#71717a; --l0:#f59e0b; --l1:#3b82f6; --l2:#8b5cf6; }}
  * {{ margin:0; padding:0; box-sizing:border-box; }}
  body {{ font-family:'SF Mono','Cascadia Code','Fira Code',monospace; background:var(--bg); color:var(--t); line-height:1.6; }}
  a {{ color:var(--l1); text-decoration:none; }} a:hover {{ text-decoration:underline; }}
  .hdr {{ border-bottom:1px solid var(--b); padding:1.5rem 2rem; display:flex; justify-content:space-between; align-items:center; }}
  .hdr h1 {{ font-size:1.2rem; }} .hdr .sub {{ color:var(--td); font-size:0.8rem; }}
  .wrap {{ display:flex; height:calc(100vh - 70px); }}
  .side {{ width:280px; min-width:280px; border-right:1px solid var(--b); overflow-y:auto; padding:1rem 0; }}
  .side::-webkit-scrollbar {{ width:5px; }} .side::-webkit-scrollbar-thumb {{ background:var(--b); border-radius:3px; }}
  .lvl {{ padding:0.5rem 1rem 0.2rem; font-size:0.65rem; font-weight:700; text-transform:uppercase; letter-spacing:0.06em; }}
  .lvl.l0 {{ color:var(--l0); }} .lvl.l1 {{ color:var(--l1); }} .lvl.l2 {{ color:var(--l2); }}
  .ni {{ padding:0.35rem 1rem 0.35rem 1.4rem; font-size:0.82rem; color:var(--tm); cursor:pointer; border-left:2px solid transparent; display:flex; justify-content:space-between; align-items:center; transition:all .12s; }}
  .ni:hover {{ background:var(--s); color:var(--t); }}
  .ni.on {{ background:var(--s2); color:var(--t); border-left-color:var(--l1); }}
  .ni .ln {{ font-size:0.68rem; color:var(--td); background:var(--s2); padding:1px 5px; border-radius:3px; }}
  .ct {{ flex:1; overflow-y:auto; padding:2rem 3rem; max-width:850px; }}
  .ct::-webkit-scrollbar {{ width:5px; }} .ct::-webkit-scrollbar-thumb {{ background:var(--b); border-radius:3px; }}
  .ch {{ margin-bottom:1.2rem; padding-bottom:0.8rem; border-bottom:1px solid var(--b); }}
  .ch .bc {{ font-size:0.72rem; color:var(--td); margin-bottom:0.3rem; }}
  .ch h2 {{ font-size:1.05rem; }}
  .badge {{ display:inline-block; font-size:0.62rem; font-weight:700; padding:2px 7px; border-radius:3px; margin-left:0.5rem; vertical-align:middle; }}
  .badge.l0 {{ background:rgba(245,158,11,.15); color:var(--l0); }}
  .badge.l1 {{ background:rgba(59,130,246,.15); color:var(--l1); }}
  .badge.l2 {{ background:rgba(139,92,246,.15); color:var(--l2); }}
  .md {{ font-size:0.85rem; line-height:1.7; }}
  .md h1 {{ font-size:1.15rem; margin:1.3rem 0 .7rem; font-weight:600; }}
  .md h2 {{ font-size:1rem; margin:1.1rem 0 .5rem; font-weight:600; }}
  .md h3 {{ font-size:.88rem; margin:.8rem 0 .4rem; font-weight:600; color:var(--tm); }}
  .md p {{ margin:.4rem 0; color:var(--tm); }}
  .md ul,.md ol {{ margin:.4rem 0; padding-left:1.4rem; color:var(--tm); }}
  .md li {{ margin:.2rem 0; }}
  .md strong {{ color:var(--t); font-weight:600; }}
  .md code {{ background:var(--s2); padding:2px 5px; border-radius:3px; font-size:.78rem; color:#e2b86b; }}
  .md pre {{ background:var(--s); border:1px solid var(--b); border-radius:6px; padding:.8rem; overflow-x:auto; margin:.6rem 0; }}
  .md pre code {{ background:none; padding:0; color:var(--tm); }}
  .md table {{ width:100%; border-collapse:collapse; margin:.6rem 0; font-size:.78rem; }}
  .md th {{ text-align:left; padding:.4rem .7rem; border-bottom:2px solid var(--b); color:var(--t); font-weight:600; }}
  .md td {{ padding:.35rem .7rem; border-bottom:1px solid var(--b); color:var(--tm); }}
  .md tr:hover td {{ background:var(--s); }}
  .md hr {{ border:none; border-top:1px solid var(--b); margin:1.2rem 0; }}
  .md blockquote {{ border-left:3px solid var(--b); padding-left:.8rem; color:var(--td); margin:.6rem 0; }}
  .sts {{ display:flex; gap:.8rem; margin:1rem 0; flex-wrap:wrap; }}
  .st {{ background:var(--s); border:1px solid var(--b); border-radius:6px; padding:.7rem; min-width:120px; }}
  .st .v {{ font-size:1.1rem; font-weight:700; }} .st .l {{ font-size:.65rem; color:var(--td); margin-top:.15rem; }}
  @media(max-width:700px) {{ .wrap {{ flex-direction:column; height:auto; }} .side {{ width:100%; min-width:100%; max-height:35vh; border-right:none; border-bottom:1px solid var(--b); }} .ct {{ padding:1rem; }} }}
</style>
</head>
<body>
<div class="hdr"><div><h1>{project_name}</h1></div><div class="sub">L0: {l0}L &middot; L1: {l1c} files/{l1}L &middot; L2: {l2c} files/{l2}L</div></div>
<div class="wrap"><div class="side" id="sb"></div><div class="ct" id="ct"></div></div>
<script>
const DOCS={docs_json};
const CONTENT={content_json};
function rmd(m){{let h=m;h=h.replace(/```(\\w*)\\n([\\s\\S]*?)```/g,(_,l,c)=>'<pre><code>'+c.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').trim()+'</code></pre>');h=h.replace(/^(\\|.+\\|)\\n(\\|[\\s\\-:|]+\\|)\\n((?:\\|.+\\|\\n?)*)/gm,(_,hd,s,bd)=>{{let ths=hd.split('|').filter(c=>c.trim()).map(c=>'<th>'+il(c.trim())+'</th>').join('');let rs=bd.trim().split('\\n').map(r=>{{let cs=r.split('|').filter(c=>c.trim()).map(c=>'<td>'+il(c.trim())+'</td>').join('');return'<tr>'+cs+'</tr>'}}).join('');return'<table><thead><tr>'+ths+'</tr></thead><tbody>'+rs+'</tbody></table>'}});h=h.replace(/^### (.+)$/gm,'<h3>$1</h3>');h=h.replace(/^## (.+)$/gm,'<h2>$1</h2>');h=h.replace(/^# (.+)$/gm,'<h1>$1</h1>');h=h.replace(/^> (.+)$/gm,'<blockquote><p>$1</p></blockquote>');h=h.replace(/^---$/gm,'<hr>');h=h.replace(/^- (.+)$/gm,'<li>$1</li>');h=h.replace(/((?:<li>.*<\\/li>\\n?)+)/g,'<ul>$1</ul>');h=h.replace(/^\\d+\\. (.+)$/gm,'<li>$1</li>');h=h.replace(/^(?!<[hupoltbs]|$|\\s*$)(.+)$/gm,'<p>$1</p>');h=il(h);return h}}
function il(t){{t=t.replace(/`([^`]+)`/g,'<code>$1</code>');t=t.replace(/\\*\\*(.+?)\\*\\*/g,'<strong>$1</strong>');t=t.replace(/\\*(.+?)\\*/g,'<em>$1</em>');t=t.replace(/\\[([^\\]]+)\\]\\(([^)]+)\\)/g,'<a href="$2">$1</a>');return t}}
function lN(l){{return l===0?'Level 0 — Apex':l===1?'Level 1 — Playbook':l===2?'Level 2 — Reference':''}}
function lC(l){{return l===0?'l0':l===1?'l1':l===2?'l2':''}}
function buildSb(){{const sb=document.getElementById('sb');let h='';let cl=-1;for(const d of DOCS.project.docs){{if(d.level!==cl){{cl=d.level;h+='<div class="lvl '+lC(d.level)+'">'+lN(d.level)+'</div>'}}const n=CONTENT[d.id]?CONTENT[d.id].split('\\n').length:0;h+='<div class="ni" data-id="'+d.id+'" onclick="show(\\''+d.id+'\\')"><span>'+d.title+'</span><span class="ln">'+n+'L</span></div>'}}sb.innerHTML=h}}
function show(id){{document.querySelectorAll('.ni').forEach(e=>e.classList.remove('on'));const a=document.querySelector('.ni[data-id="'+id+'"]');if(a)a.classList.add('on');const ct=document.getElementById('ct');const d=DOCS.project.docs.find(x=>x.id===id);if(!d||!CONTENT[id]){{ct.innerHTML='<p style="color:var(--td)">No content.</p>';return}}const b=d.level!==null?'<span class="badge '+lC(d.level)+'">'+lN(d.level)+'</span>':'';ct.innerHTML='<div class="ch"><div class="bc">'+d.path+'</div><h2>'+d.title+b+'</h2></div><div class="md">'+rmd(CONTENT[id])+'</div>';ct.scrollTop=0}}
buildSb();
if(DOCS.project.docs.length)show(DOCS.project.docs[0].id);
</script>
</body>
</html>'''

    out_path = os.path.join(project_dir, "docs", "viewer.html")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w") as f:
        f.write(html)
    print(f"Built {out_path} — {len(docs)} documents, L0:{l0}L L1:{l1c}/{l1}L L2:{l2c}/{l2}L")
    return out_path


if __name__ == "__main__":
    if len(sys.argv) < 2:
        # Default: build for all example projects
        examples = os.path.join(os.path.dirname(os.path.abspath(__file__)), "examples")
        for name in sorted(os.listdir(examples)):
            path = os.path.join(examples, name)
            if os.path.isdir(path):
                generate(path)
    else:
        generate(sys.argv[1])
