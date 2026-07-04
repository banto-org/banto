#!/usr/bin/env python3
"""ai_context_combined.py — standalone generation of full-combined.txt (no SoftMatcha dependency, stdlib only)

search-native-migration spec T1-1. Ports _build_combined_text / _parse_jsonl_sessions /
_mask_secrets / _extract_tags from the old softmatcha-mcp/server.py, and changes the full
scope to a per-session incremental cache (sessions-cache/<id>.txt, mtime comparison).

search-layer-redesign spec branch 1A (2026-07-04): the project scope (formerly its own
output file) is retired — search ranking (store-query.sh) reads decisions/docs directly
and never read it. Only the full scope (full-combined.txt: decisions/docs + session
history) remains.

usage:
  python3 ai_context_combined.py --project-root <dir> [--base <ai-context base>] [--scope full]

When --base is omitted, resolves the central store via resolve-store-path.sh --store-dir,
falling back to <project-root>/.ai-context (legacy) when unregistered.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path


# ---------------------------------------------------------------- resolution

def resolve_base(project_root: Path) -> Path:
    """Resolve the ai-context base (store dir when registered in the central store, else legacy)."""
    resolver = Path(__file__).resolve().parent / "resolve-store-path.sh"
    if resolver.exists():
        try:
            proc = subprocess.run(
                ["sh", str(resolver), "--store-dir", str(project_root)],
                capture_output=True, text=True, timeout=10,
            )
            if proc.returncode == 0 and proc.stdout.strip():
                return Path(proc.stdout.strip())
        except (OSError, subprocess.SubprocessError):
            pass
    return project_root / ".ai-context"


def load_config(base: Path) -> dict:
    config_path = base / "config.json"
    if config_path.exists():
        try:
            return json.loads(config_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return {}
    return {}


def extra_docs_dirs(config: dict, project_root: Path) -> list[Path]:
    dirs = []
    for d in config.get("extra_docs_dirs", []):
        p = (project_root / d).resolve()
        if p.exists() and p.is_dir():
            dirs.append(p)
    return dirs


# ---------------------------------------------------------------- masking / tags

def mask_secrets(text: str) -> str:
    text = re.sub(r"sk-[A-Za-z0-9_-]{20,}", "[MASKED]", text)
    # GitHub tokens: PAT (ghp_), OAuth (gho_), server-to-server (ghs_), fine-grained PAT (github_pat_)
    text = re.sub(r"gh[ops]_[A-Za-z0-9]{36,}", "[MASKED]", text)
    text = re.sub(r"github_pat_[A-Za-z0-9_]{22,}", "[MASKED]", text)
    # Slack tokens (bot/user/app-level/refresh/legacy): xoxb-/xoxa-/xoxp-/xoxr-/xoxs-
    text = re.sub(r"xox[baprs]-[A-Za-z0-9-]{10,}", "[MASKED]", text)
    text = re.sub(r"Bearer\s+[A-Za-z0-9._-]{20,}", "Bearer [MASKED]", text)
    return text


def extract_tags(content: str, filename: str) -> str:
    # i18n: 「**タグ**:」 is the tag-line format of JP decision docs — parsing logic, do not translate.
    tag_match = re.search(r"\*\*タグ\*\*:\s*(.+)", content)
    if tag_match:
        return tag_match.group(1).strip()
    parts = filename.split("_", 1)
    if len(parts) > 1:
        topic = parts[1].rsplit("_", 1)[0] if "_" in parts[1] else parts[1]
        return ",".join(topic.split("-"))
    return filename


def is_subpath(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


# ---------------------------------------------------------------- project scope

def build_project_parts(base: Path, config: dict, project_root: Path) -> list[str]:
    dirs_to_include: list[tuple[str, Path]] = [
        ("decision", base / "decisions"),
        ("doc", base / "docs"),
    ]
    for extra in extra_docs_dirs(config, project_root):
        dirs_to_include.append(("doc", extra))

    parts: list[str] = []
    for source_type, dir_path in dirs_to_include:
        if not dir_path.exists():
            continue
        for file_path in sorted(dir_path.rglob("*.md")):
            rel = file_path.relative_to(base) if is_subpath(file_path, base) else file_path.relative_to(project_root)
            content = file_path.read_text(encoding="utf-8")
            tags = extract_tags(content, file_path.stem)
            parts.append(f"<<<FILE:{source_type}:{rel}:tags={tags}>>>")
            parts.append(content)
            parts.append("")
    return parts


# ---------------------------------------------------------------- full scope (incremental)

def find_session_dir(project_root: Path) -> Path | None:
    claude_projects = Path.home() / ".claude" / "projects"
    if not claude_projects.exists():
        return None
    encoded = str(project_root).replace("/", "-")
    session_dir = claude_projects / encoded
    return session_dir if session_dir.exists() else None


def extract_session_text(jsonl_path: Path) -> str:
    """Extract human-readable text from one session JSONL (secrets masked)."""
    parts: list[str] = []
    try:
        with open(jsonl_path, encoding="utf-8") as f:
            for line in f:
                if not line.strip():
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                entry_type = entry.get("type", "")
                if entry_type not in ("user", "assistant"):
                    continue
                msg = entry.get("message", {})
                if not isinstance(msg, dict):
                    continue
                content = msg.get("content", "")
                role = "Human" if entry_type == "user" else "Assistant"
                text = ""
                if isinstance(content, str):
                    text = content
                elif isinstance(content, list):
                    text_parts = [
                        b.get("text", "") for b in content
                        if isinstance(b, dict) and b.get("type") == "text"
                    ]
                    text = "\n".join(text_parts)
                if not text.strip():
                    continue
                parts.append(f"### {role}\n{mask_secrets(text)}\n")
    except (OSError, UnicodeDecodeError):
        return ""
    return "\n".join(parts)


def build_session_parts(base: Path, project_root: Path) -> list[str]:
    """Incremental cache: re-parse only JSONLs whose mtime changed, then return the concatenated caches."""
    session_dir = find_session_dir(project_root)
    if session_dir is None:
        return []
    cache_dir = base / "sessions-cache"
    cache_dir.mkdir(parents=True, exist_ok=True)

    jsonls = {p.stem: p for p in sorted(session_dir.glob("*.jsonl"))}

    # Clean up caches of sessions that disappeared
    for stale in cache_dir.glob("*.txt"):
        if stale.stem not in jsonls:
            stale.unlink(missing_ok=True)

    parts: list[str] = []
    for session_id, jsonl_path in jsonls.items():
        cache_path = cache_dir / f"{session_id}.txt"
        if not cache_path.exists() or cache_path.stat().st_mtime < jsonl_path.stat().st_mtime:
            cache_path.write_text(extract_session_text(jsonl_path), encoding="utf-8")
        session_text = cache_path.read_text(encoding="utf-8")
        if not session_text.strip():
            continue
        parts.append(f"<<<FILE:session:{session_id}:tags=chat,session>>>")
        parts.append(session_text)
        parts.append("")
    return parts


# ---------------------------------------------------------------- main

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--project-root", required=True)
    ap.add_argument("--base", default="")
    ap.add_argument("--scope", choices=["full"], default="full")
    args = ap.parse_args()

    project_root = Path(args.project_root).resolve()
    base = Path(args.base).resolve() if args.base else resolve_base(project_root)
    if not base.exists():
        print(f"ai_context_combined: base does not exist: {base}", file=sys.stderr)
        return 1
    config = load_config(base)

    parts = build_project_parts(base, config, project_root)
    parts += build_session_parts(base, project_root)
    out = base / "full-combined.txt"
    out.write_text("\n".join(parts), encoding="utf-8")
    print(f"{out} ({out.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
