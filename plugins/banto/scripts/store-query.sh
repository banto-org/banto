#!/bin/sh
# store-query.sh — ai-context store の FTS5 セクション検索（search skill の内容層エンジン）。
#
# Usage: store-query.sh [--all | --project <name>] <terms...>
#        store-query.sh --related <relpath の一意な断片>
#   既定はカレントプロジェクトに絞る。--all で全 store 横断（「前にどのプロジェクトで？」）。
#   語は AND 結合。3 文字未満の語を含むときは LIKE 全走査へ自動フォールバック（trigram の制約）。
#   --related は frontmatter `related:` から抽出した参照グラフの芋づる（→ 参照先 / ← 被参照）。
# 出力: project | relpath#見出し | L開始-終了 | 抜粋  （BM25 上位 8 件）
#   ヒット後は Read の offset/limit で行範囲だけ読む（全文 read しない）。relpath は db ルート相対。
# fail-open: sqlite3 / db 不在は exit 1 + 一行案内（呼び出し側は combined.txt 経路へ）。
# 索引は store_index_gen.py が SessionStart / store 書き込み時に自動再生成する（コミットされない）。
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

SCOPE="project"
PROJECT=""
MODE="search"
while [ $# -gt 0 ]; do
    case "$1" in
        --all) SCOPE="all"; shift ;;
        --project) PROJECT="${2:-}"; SCOPE="project"; shift 2 ;;
        --related) MODE="related"; SCOPE="all"; shift ;;
        *) break ;;
    esac
done
[ $# -ge 1 ] || { echo "usage: store-query.sh [--all | --project <name>] <terms...> | --related <relpath 断片>" >&2; exit 1; }

command -v sqlite3 >/dev/null 2>&1 || { echo "store-query: sqlite3 not found — fall back to combined.txt search" >&2; exit 1; }

# db 解決: $STORE_QUERY_DB > store ルート（.ai-context-store マーカー）> base 直下
DB="${STORE_QUERY_DB:-}"
BASE=""
if [ -z "$DB" ]; then
    BASE=$(sh "$SCRIPT_DIR/_ai-context-paths.sh" --resolve "$PWD" 2>/dev/null)
    [ -n "$BASE" ] || { echo "store-query: ai-context base unresolved — fall back to combined.txt search" >&2; exit 1; }
    ROOT=$(dirname "$BASE")
    [ -f "$ROOT/.ai-context-store" ] || ROOT="$BASE"
    DB="$ROOT/.store-index.db"
fi
[ -f "$DB" ] || { echo "store-query: index not found ($DB) — fall back to combined.txt search" >&2; exit 1; }

# 既定のプロジェクト絞り込み（--all 指定時はなし）
WHERE_PROJ=""
if [ "$SCOPE" = "project" ]; then
    [ -n "$PROJECT" ] || { [ -n "$BASE" ] || BASE=$(sh "$SCRIPT_DIR/_ai-context-paths.sh" --resolve "$PWD" 2>/dev/null); PROJECT=$(basename "${BASE:-$PWD}"); }
    _proj_esc=$(printf '%s' "$PROJECT" | sed "s/'/''/g")
    WHERE_PROJ=" AND project = '$_proj_esc'"
fi

# --- --related: 参照グラフの芋づる（related: 抽出エッジ。→ 参照先 / ← 被参照） ---
if [ "$MODE" = "related" ]; then
    _frag=$(printf '%s' "$1" | sed "s/'/''/g")
    TREL=$(sqlite3 "$DB" "SELECT relpath FROM docs WHERE relpath LIKE '%$_frag%' ORDER BY length(relpath) LIMIT 1")
    [ -n "$TREL" ] || { echo "store-query: no doc matches fragment: $1" >&2; exit 1; }
    _trel_esc=$(printf '%s' "$TREL" | sed "s/'/''/g")
    echo "doc: $TREL"
    echo "→ 参照している (related:)"
    sqlite3 -separator ' | ' "$DB" "SELECT '  ' || r.to_ref,
        COALESCE((SELECT d.relpath FROM docs d
                  WHERE d.relpath LIKE r.from_project || '/' || r.to_ref || '%' LIMIT 1), '(未解決)')
        FROM refs r WHERE r.from_relpath = '$_trel_esc'"
    echo "← 参照されている (referenced by)"
    sqlite3 -separator ' | ' "$DB" "SELECT '  ' || r.from_relpath FROM refs r
        WHERE '$_trel_esc' LIKE r.from_project || '/' || r.to_ref || '%'"
    exit 0
fi

short=0
for t in "$@"; do
    [ "$(printf '%s' "$t" | wc -m)" -lt 3 ] && short=1
done

if [ "$short" = 0 ]; then
    MATCH=""
    for t in "$@"; do
        esc=$(printf '%s' "$t" | sed 's/"/""/g')
        MATCH="$MATCH${MATCH:+ AND }\"$esc\""
    done
    MATCH_SQL=$(printf '%s' "$MATCH" | sed "s/'/''/g")
    sqlite3 -separator ' | ' "$DB" "SELECT project, relpath || '#' || heading,
        'L' || line_start || '-' || line_end,
        replace(snippet(sections, 7, '<<', '>>', '…', 20), char(10), ' ')
        FROM sections WHERE sections MATCH '$MATCH_SQL'$WHERE_PROJ
        ORDER BY bm25(sections) LIMIT 8"
else
    W=""
    for t in "$@"; do
        esc=$(printf '%s' "$t" | sed "s/'/''/g")
        W="$W${W:+ AND }body LIKE '%$esc%'"
    done
    sqlite3 -separator ' | ' "$DB" "SELECT project, relpath || '#' || heading,
        'L' || line_start || '-' || line_end, substr(replace(body, char(10), ' '), 1, 120)
        FROM sections WHERE $W$WHERE_PROJ LIMIT 8"
fi
