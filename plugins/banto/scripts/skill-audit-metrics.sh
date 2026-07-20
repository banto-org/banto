#!/bin/sh
# skill-audit-metrics.sh <skill-dir>
#
# skill-audit skill 用の決定論ヘルパー。単一 skill ディレクトリを引数に取り、
# コンテキストエンジニアリング監査 7 軸（skills/skill-audit/references/axes.md）の
# 材料となる機械計測を出力する。
#
# 出力セクション:
#   (a) SKILL.md / 各 references/*.md のバイト数・行数
#   (b) frontmatter description の文字数
#   (c) 経緯メタ情報パターン（hooks/ja-lint.py の META_PATTERNS と同一群）のヒット行
#   (d) ファイル間の重複段落（正規化した 30 字以上の行が複数ファイルに一致するもの）
#   (e) Claude 固有トークン（Task/Skill/CLAUDE_PLUGIN_ROOT/hook/allowed-tools/SKILL.md）の出現数
#   (f) model 指定（model: / model=）の抽出行
#
# 対象ファイルの列挙は word-splitting に依存する（plugin 内パスは空白を含まない）。
set -eu

DIR=${1:?usage: skill-audit-metrics.sh <skill-dir>}
[ -d "$DIR" ] || { echo "skill-audit-metrics: no such directory: $DIR" >&2; exit 1; }

SKILL_MD="$DIR/SKILL.md"
[ -f "$SKILL_MD" ] || { echo "skill-audit-metrics: no SKILL.md in $DIR" >&2; exit 1; }

FILES="$SKILL_MD"
if [ -d "$DIR/references" ]; then
    for f in "$DIR"/references/*.md "$DIR"/references/*/*.md; do
        [ -f "$f" ] && FILES="$FILES $f"
    done
fi
# scripts/ は散文計測の対象外だが、存在の把握のため (a) にサイズだけ出す
SCRIPT_FILES=""
if [ -d "$DIR/scripts" ]; then
    for f in "$DIR"/scripts/*; do
        [ -f "$f" ] && SCRIPT_FILES="$SCRIPT_FILES $f"
    done
fi

echo "=== (a) file size ==="
for f in $FILES $SCRIPT_FILES; do
    bytes=$(wc -c < "$f" | tr -d ' ')
    lines=$(wc -l < "$f" | tr -d ' ')
    printf '%s\tbytes=%s\tlines=%s\n' "$f" "$bytes" "$lines"
done

echo "=== (b) description length ==="
DESC=$(awk '
  /^description:[ \t]*\|/ { inblock = 1; next }                     # ブロック形式 description: |
  /^description:/ { sub(/^description:[ \t]*/, ""); print; next }   # 単一行形式
  inblock && (/^[A-Za-z_-]+:/ || /^---[ \t]*$/) { inblock = 0 }     # 次のキーか frontmatter 終端で停止
  inblock { print }
' "$SKILL_MD")
# LC_ALL を UTF-8 に固定して文字数を数える（C ロケールの wc -m はバイト数を返す）
DESC_LEN=$(printf '%s' "$DESC" | LC_ALL=en_US.UTF-8 wc -m | tr -d ' ')
echo "description chars=$DESC_LEN"

echo "=== (c) process-history meta-info pattern hits ==="
META_PATS='（最新）|（新規）|新規追加|今回追加|従来は|から変更|旧版では'
for f in $FILES; do
    grep -nE "$META_PATS" "$f" 2>/dev/null | sed "s#^#$f:#"
done

echo "=== (d) duplicate paragraphs across files (normalized lines >=30 chars) ==="
awk '
length($0) >= 30 {
    line = $0
    gsub(/^[ \t]+|[ \t]+$/, "", line)
    if (line == "") next
    if (!(line in seen)) {
        seen[line] = FILENAME
        cnt[line] = 1
    } else if (index(seen[line], FILENAME) == 0) {
        seen[line] = seen[line] "," FILENAME
        cnt[line]++
    }
}
END {
    for (k in cnt) {
        if (cnt[k] > 1) print seen[k] "\t" k
    }
}
' $FILES

echo "=== (e) Claude-specific token occurrences ==="
for tok in Task Skill CLAUDE_PLUGIN_ROOT hook allowed-tools SKILL.md; do
    count=0
    for f in $FILES; do
        c=$(grep -oE "$tok" "$f" 2>/dev/null | wc -l | tr -d ' ')
        count=$((count + c))
    done
    echo "$tok=$count"
done

echo "=== (f) model directive lines ==="
for f in $FILES; do
    grep -nE '(^|[^A-Za-z])model[:=]' "$f" 2>/dev/null | sed "s#^#$f:#"
done
