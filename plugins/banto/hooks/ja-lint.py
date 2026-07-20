#!/usr/bin/env python3
"""ja-lint logic — PostToolUse(Write|Edit) で .md 書き込みの日本語ライティング規約
（~/.claude/rules/writing-ja.md）逸脱候補を warn する（block しない）。

stdin: Claude Code hook payload (JSON: tool_name / tool_input)

exit 0 常に（warn only）。stdout に警告メッセージ（最大 5 件 + 「他 N 件」）を出す。
CONTRACT.md: PostToolUse の stdout は Claude へのツールフィードバックとして注入される。

対象外: .md 以外 / i18n/en 配下 / 日本語（ひらがな・カタカナ）が閾値未満のファイル。
コードフェンス（``` ... ```）とインラインコード（`...`）は走査から除外する。
"""
import sys, json, re

JA_THRESHOLD = 10  # ひらがな + カタカナの最小出現数（英語主体の.mdの誤検知を避ける）
MAX_SHOWN = 5

HIRAGANA_KATAKANA = re.compile(r"[぀-ヿ]")
JA_CHAR = re.compile(r"[぀-ヿ一-鿿]")

# 文末規則違反（writing-ja.md 3節: だ・である・です・ます は使わない）
SENTENCE_END_NG = ("です。", "ます。", "だ。", "である。")

# 経緯メタ情報パターン（正本ドキュメントに残すべきでない一時的な注記）
META_PATTERNS = ("（最新）", "（新規）", "新規追加", "今回追加", "従来は", "から変更", "旧版では")

# decisions/ 限定: 会話の逐語引用（口語で終わる「」引用）。decision は生成物・学習物の正本なので
# 発言は要旨へ丸める（例: owner 指示（要旨）: X を実装する）。warn only。
COLLOQUIAL_QUOTE = re.compile(
    r"(てほしい|ておいて|てもらえるか|てもらえますか|でしょうか|ましょうか|ますか|ですか|かな|よね|ですね|だよな|ください|頼む|お願い)」"
)


def strip_code_fences(text: str) -> str:
    # 3連バッククォートのフェンスブロックを丸ごと除去（開始行・終了行も含む）
    text = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
    # インラインコード（`...`）は中身だけ除去（前後の日本語境界判定を壊さないよう空白に置換）
    text = re.sub(r"`[^`\n]*`", " ", text)
    return text


def count_ja(text: str) -> int:
    return len(HIRAGANA_KATAKANA.findall(text))


def check_lines(text: str, is_decision: bool = False):
    findings = []
    for i, raw in enumerate(text.split("\n"), start=1):
        line = raw.rstrip()
        stripped = line.lstrip()
        if stripped.startswith(">"):
            continue
        if not line:
            continue

        # (d) decisions/ 限定: 会話の逐語引用（口語終わりの「」）
        if is_decision:
            m = COLLOQUIAL_QUOTE.search(line)
            if m:
                findings.append(
                    f"L{i}: colloquial verbatim quote `…{m.group(0)}` in a decision — 発言は要旨へ丸める（例: owner 指示（要旨）: X を実装する）"
                )

        # (a) 文末規則
        for ng in SENTENCE_END_NG:
            if line.endswith(ng):
                findings.append(f"L{i}: sentence ends with `{ng}` (writing-ja.md: no だ/である/です/ます endings)")
                break

        # (b) 和文と英数字の境界の半角スペース欠落
        m = re.search(r"[぀-ヿ一-鿿][A-Za-z0-9]|[A-Za-z0-9][぀-ヿ一-鿿]", line)
        if m:
            snippet = line[max(0, m.start() - 6):m.end() + 6]
            findings.append(f"L{i}: missing half-width space at JA/ASCII boundary near \"{snippet}\"")

        # (c) 経緯メタ情報パターン
        for pat in META_PATTERNS:
            if pat in line:
                findings.append(f"L{i}: process-history annotation `{pat}` found (should not persist in a canonical doc)")
                break

    return findings


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    tool_name = payload.get("tool_name") or ""
    if tool_name not in ("Write", "Edit"):
        sys.exit(0)

    tool_input = payload.get("tool_input") or {}
    file_path = tool_input.get("file_path") or ""
    if not file_path.endswith(".md"):
        sys.exit(0)
    if "/i18n/en/" in file_path:
        sys.exit(0)

    content = tool_input.get("content")
    if content is None:
        content = tool_input.get("new_string")
    if not content:
        sys.exit(0)

    body = strip_code_fences(content)
    if count_ja(body) < JA_THRESHOLD:
        sys.exit(0)

    findings = check_lines(body, is_decision="/decisions/" in file_path)
    if not findings:
        sys.exit(0)

    shown = findings[:MAX_SHOWN]
    rest = len(findings) - len(shown)
    print(f"[ja-lint] {len(findings)} 件の日本語ライティング規約逸脱候補を検出（~/.claude/rules/writing-ja.md 参照。warn のみ）: {file_path}")
    for f in shown:
        print(f"  - {f}")
    if rest > 0:
        print(f"  ...他 {rest} 件")

    sys.exit(0)


if __name__ == "__main__":
    main()
