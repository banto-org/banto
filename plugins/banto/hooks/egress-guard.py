#!/usr/bin/env python3
"""egress-guard logic — PreToolUse(Write|Edit|NotebookEdit) で客先 egress への内部名/PII 流出を検出。

stdin: Claude Code hook payload (JSON: tool_name / tool_input)
argv[1]: 名前レジストリ path（1 行 1 エントリ、# コメント可、`re:` 接頭辞で正規表現）

exit 0: 許可（安全パス / ヒット無し / 解析不能は fail-open しない＝ブロックしない）
exit 2: ブロック（客先パス × 名前ヒット）。stderr に理由 + マスク提案 + escape 手順。

設計: decisions/2026-05-30_001_ai-context-pii-name-isolation_tatsuru-okada-business.md
"""
import sys, os, json, re

PLUGIN_NAME = "banto"


def _is_own_source_tree(path: str) -> bool:
    """書き込み先が Banto 自身のソースツリー / 中央 store checkout 配下か。
    repo 名の文字列一致ではなく marker で判定する:
      - .claude-plugin/plugin.json の name == banto（plugin dev checkout / installed copy）
      - repo 直下 marker `.ai-context-store`（中央 store。odd-kill-switch と同じ規約）
    親ディレクトリ方向に最大 12 階層探索。"""
    d = path if os.path.isdir(path) else os.path.dirname(path)
    if not os.path.isabs(d):
        return False
    for _ in range(12):
        for mj in (
            os.path.join(d, ".claude-plugin", "plugin.json"),
            os.path.join(d, "plugins", PLUGIN_NAME, ".claude-plugin", "plugin.json"),
        ):
            try:
                with open(mj, encoding="utf-8") as f:
                    if json.load(f).get("name") == PLUGIN_NAME:
                        return True
            except Exception:
                pass
        if os.path.exists(os.path.join(d, ".ai-context-store")):
            return True
        nd = os.path.dirname(d)
        if nd == d:
            break
        d = nd
    return False


def is_internal_path(abs_path: str, home: str) -> bool:
    """客先成果物ではない安全パス（= スキャン対象外）か。"""
    p = abs_path
    if "/.ai-context/" in p or p.endswith("/.ai-context"):
        return True
    if p.startswith(home + "/.claude/"):
        return True
    # plugin ソース / store チェックアウト（内部）— marker ベース判定
    if _is_own_source_tree(p):
        return True
    # 明示 safelist（: 区切りの path prefix）
    for pre in (os.environ.get("BANTO_EGRESS_SAFE_PATHS", "") or "").split(":"):
        pre = pre.strip()
        if pre and p.startswith(os.path.abspath(os.path.expanduser(pre))):
            return True
    return False


def load_registry(path: str):
    literals, regexes = [], []
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                s = line.strip()
                if not s or s.startswith("#"):
                    continue
                if s.startswith("re:"):
                    pat = s[3:].strip()
                    if pat:
                        try:
                            regexes.append((pat, re.compile(pat, re.IGNORECASE)))
                        except re.error:
                            pass  # 不正な正規表現はスキップ（guard を壊さない）
                else:
                    literals.append(s)
    except OSError:
        pass
    return literals, regexes


def main():
    if len(sys.argv) < 2:
        sys.exit(0)
    registry_path = sys.argv[1]
    home = os.path.expanduser("~")

    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)  # 解析不能 → ブロックしない（誤爆回避）

    ti = payload.get("tool_input", {}) or {}
    file_path = ti.get("file_path", "") or ti.get("path", "") or ti.get("notebook_path", "") or ""
    if not file_path:
        sys.exit(0)

    abs_path = os.path.abspath(os.path.expanduser(file_path))
    if is_internal_path(abs_path, home):
        sys.exit(0)  # 内部パス（.ai-context / ~/.claude / plugin）は対象外

    # スキャン対象の本文を収集（Write: content/file_text, Edit: new_string,
    # MultiEdit: edits[].new_string, NotebookEdit: new_source）
    parts = []
    for k in ("content", "file_text", "new_string", "new_str", "new_source"):
        v = ti.get(k)
        if isinstance(v, str):
            parts.append(v)
    for e in ti.get("edits", []) or []:
        if isinstance(e, dict):
            v = e.get("new_string") or e.get("new_str")
            if isinstance(v, str):
                parts.append(v)
    content = "\n".join(parts)
    if not content.strip():
        sys.exit(0)

    literals, regexes = load_registry(registry_path)
    cl = content.lower()
    hits = []
    for lit in literals:
        if lit.lower() in cl:
            hits.append(lit)
    for pat, rx in regexes:
        if rx.search(content):
            hits.append("re:" + pat)

    if not hits:
        sys.exit(0)

    # ブロック
    uniq = []
    for h in hits:
        if h not in uniq:
            uniq.append(h)
    shown = ", ".join(uniq[:8]) + (" …" if len(uniq) > 8 else "")
    msg = (
        "[egress-guard] Internal names/PII were about to leak into a client deliverable — blocked.\n"
        f"  Write target: {file_path}\n"
        f"  Detected (name registry match): {shown}\n"
        "  Fix: mask the names (e.g. 'Person A' / 'Company X') or replace proper nouns with generic terms.\n"
        "  Only if this write is legitimate: re-run with BANTO_ALLOW_NAMES=1 (mind cross-project confidentiality).\n"
        "  Registry: ~/.claude/banto-name-registry"
    )
    sys.stderr.write(msg + "\n")
    sys.exit(2)


if __name__ == "__main__":
    main()
