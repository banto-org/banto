#!/usr/bin/env python3
"""store_index_gen.py — ai-context store の FTS5 セクション索引を生成（決定論・冪等・fail-open）。

正本は md、索引はコミットしないローカル派生物（git 管理外・消えても 2.5 秒で再生成できる）。
decision 2026-07-02-215442（db 非コミット・各自ローカル再生成）/ 223134（R5 実測）の実装。

- 対象: base の親ディレクトリに .ai-context-store マーカーがあれば store ルート配下の全 *.md
  （プロジェクト横断）、無ければ base 配下のみ。meta/ tmp/ .git/ は除外。
- 鮮度: db より新しい md が無ければ何もしない（--force で強制再構築）。
- 原子性: 一時ファイルに構築して os.replace で差し替え（読者は旧 db を読み続けられる）。
- fail-open: FTS5 が無い・書き込めない等は exit 0（ハーネスを止めない）。
- store ルートの .gitignore に .store-index.db* を冪等追記（誤コミット防止）。

Usage: store_index_gen.py --base <dir> [--force]
"""
import argparse
import os
import re
import sqlite3
import sys
import time
from pathlib import Path

SKIP_DIRS = {".git", "tmp", "meta"}
DB_NAME = ".store-index.db"


def doc_type_of(rel: str) -> str:
    parts = rel.split("/")
    # rel は root 相対。store ルート走査時は parts[0] = プロジェクト名
    sub = parts[1:] if len(parts) > 1 else parts
    if not sub:
        return "doc"
    if sub[0] == "decisions":
        return "decision"
    if sub[0] == "docs":
        if len(sub) >= 2 and sub[1] == "research":
            return "research"
        if len(sub) >= 2 and sub[1] == "specs":
            if rel.endswith("_plan.md"):
                return "plan"
            if rel.endswith("_tasks.md"):
                return "tasks"
            return "spec"
        if len(sub) >= 2 and sub[1] == "knowledges":
            return "knowledge"
        m = re.match(r"^\[([A-Za-z]+)\]", sub[-1])
        return m.group(1).lower() if m else "doc"
    if sub[0] == "sessions":
        return "session"
    if sub[0] == "tasks":
        return "task"
    if sub[0] == "workspaces":
        return "workspace"
    return "doc"


def frontmatter_field(text: str, field: str) -> str:
    m = re.search(rf"^{field}:\s*(.+)$", text[:2000], re.M)
    return m.group(1).strip() if m else ""


def frontmatter_related(text: str):
    """frontmatter の related: リスト（YAML の素朴なブロック形式のみ）を決定論抽出する。
    エントリは project 相対の生文字列（.md や author 接尾辞を欠くことが多い — 解決は参照側で prefix 一致）。"""
    if not text.startswith("---"):
        return []
    end = text.find("\n---", 3)
    if end < 0:
        return []
    out, in_rel = [], False
    for line in text[:end].splitlines():
        if re.match(r"^related:\s*$", line):
            in_rel = True
            continue
        if in_rel:
            m = re.match(r"^\s+-\s+(.+?)\s*$", line)
            if m:
                out.append(m.group(1).strip())
            else:
                in_rel = False
    return out


def title_of(text: str, fname: str) -> str:
    t = frontmatter_field(text, "title")
    if t:
        return t
    m = re.search(r"^#\s+(.+)$", text, re.M)
    if m:
        return m.group(1).strip()
    return fname


def sections(text: str):
    """見出し単位で分割し (heading, line_start, line_end, body) を返す（行番号は 1 始まり）。"""
    lines = text.splitlines()
    idx = [i for i, l in enumerate(lines) if re.match(r"^#{1,4}\s", l)]
    if not idx:
        yield ("(全文)", 1, len(lines), text)
        return
    if idx[0] > 0:
        yield ("(冒頭)", 1, idx[0], "\n".join(lines[: idx[0]]))
    for j, i in enumerate(idx):
        end = idx[j + 1] if j + 1 < len(idx) else len(lines)
        yield (lines[i].lstrip("# ").strip(), i + 1, end, "\n".join(lines[i:end]))


def collect_md(root: Path):
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for f in filenames:
            if f.endswith(".md"):
                out.append(Path(dirpath) / f)
    return sorted(out)


def ensure_gitignore(root: Path):
    gi = root / ".gitignore"
    line = ".store-index.db*"
    try:
        if gi.exists():
            if line in gi.read_text(errors="replace").splitlines():
                return
            with gi.open("a") as fh:
                fh.write(f"\n# FTS5 検索索引（再生成可能・コミットしない / store_index_gen.py が管理）\n{line}\n")
        else:
            gi.write_text(f"# FTS5 検索索引（再生成可能・コミットしない）\n{line}\n")
    except OSError:
        pass  # fail-open: gitignore を書けなくても索引生成は続行


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True)
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    base = Path(args.base).resolve()
    if not base.is_dir():
        return 0  # fail-open

    parent = base.parent
    if (parent / ".ai-context-store").exists():
        root, cross = parent, True
    else:
        root, cross = base, False
    db_path = root / DB_NAME

    files = collect_md(root)
    if not files:
        return 0

    if db_path.exists() and not args.force:
        newest = max(f.stat().st_mtime for f in files)
        if newest <= db_path.stat().st_mtime:
            return 0  # 鮮度 OK — 再構築不要

    tmp = root / f"{DB_NAME}.tmp.{os.getpid()}"
    try:
        con = sqlite3.connect(tmp)
        con.executescript(
            """
            CREATE TABLE docs(id INTEGER PRIMARY KEY, project TEXT, relpath TEXT, doc_type TEXT,
                              title TEXT, status TEXT, author TEXT, uri TEXT, mtime REAL, bytes INTEGER);
            CREATE TABLE refs(from_project TEXT, from_relpath TEXT, to_ref TEXT, kind TEXT);
            CREATE INDEX refs_from ON refs(from_relpath);
            CREATE VIRTUAL TABLE sections USING fts5(project, relpath, doc_type, title, heading,
                              line_start UNINDEXED, line_end UNINDEXED, body, tokenize='trigram');
            """
        )
        ndocs = nsec = 0
        for f in files:
            rel = f.relative_to(root).as_posix()
            try:
                text = f.read_text(errors="replace")
            except OSError:
                continue
            project = rel.split("/")[0] if cross else base.name
            dt = doc_type_of(rel if cross else f"{project}/{rel}")
            title = title_of(text, f.name)
            st = f.stat()
            con.execute(
                "INSERT INTO docs(project,relpath,doc_type,title,status,author,uri,mtime,bytes) VALUES(?,?,?,?,?,?,?,?,?)",
                (project, rel, dt, title,
                 frontmatter_field(text, "status"), frontmatter_field(text, "author"),
                 frontmatter_field(text, "uri"), st.st_mtime, st.st_size),
            )
            for r in frontmatter_related(text):
                con.execute("INSERT INTO refs(from_project,from_relpath,to_ref,kind) VALUES(?,?,?,?)",
                            (project, rel, r, "related"))
            ndocs += 1
            for heading, ls, le, body in sections(text):
                con.execute(
                    "INSERT INTO sections(project,relpath,doc_type,title,heading,line_start,line_end,body) VALUES(?,?,?,?,?,?,?,?)",
                    (project, rel, dt, title, heading, ls, le, body),
                )
                nsec += 1
        con.commit()
        con.execute("INSERT INTO sections(sections) VALUES('optimize')")
        con.commit()
        con.close()
        os.replace(tmp, db_path)  # 原子的差し替え（POSIX rename）
    except (sqlite3.Error, OSError):
        try:
            tmp.unlink(missing_ok=True)
        except OSError:
            pass
        return 0  # fail-open: FTS5 不在・ディスク不調等でもハーネスを止めない

    if cross:
        ensure_gitignore(root)
    print(f"store-index: {ndocs} docs / {nsec} sections -> {db_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
