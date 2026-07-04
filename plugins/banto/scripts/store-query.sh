#!/bin/sh
# store-query.sh — ai-context store の FTS5 セクション検索（search skill の内容層エンジン）。
#
# Usage: store-query.sh [--all | --project <name>] <terms...>
#        store-query.sh --related <relpath の一意な断片>
#   既定はカレントプロジェクトに絞る。--all で全 store 横断（「前にどのプロジェクトで？」）。
#   語は AND 結合。3 文字未満の語を含むときは LIKE 全走査へ自動フォールバック（trigram の制約）。
#   0 件は黙らない: 多語 AND が 0 件なら OR へ自動緩和して明示、それでも 0 件なら次の一手を出力する。
#   --related は frontmatter `related:` から抽出した参照グラフの芋づる（→ 参照先 / ← 被参照）。
#   ランキングは decision（一次文書）を優先: 派生記録（台帳・checkpoint 等）に埋もれず、
#   一次文書へ直接到達できるよう doc_type で重み付けする。
# 出力: project | relpath#見出し | L開始-終了 | 抜粋  （BM25 上位 8 件）
#   ヒット後は Read の offset/limit で行範囲だけ読む（全文 read しない）。relpath は db ルート相対。
# fail-open: sqlite3 / db 不在は exit 1 + 一行案内（呼び出し側は Grep 直接走査へフォールバック）。
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

command -v sqlite3 >/dev/null 2>&1 || { echo "store-query: sqlite3 not found — Grep 直接走査（{base}/decisions/ {base}/docs/）へフォールバック" >&2; exit 1; }

# db 解決: $STORE_QUERY_DB > store ルート（.ai-context-store マーカー）> base 直下
DB="${STORE_QUERY_DB:-}"
BASE=""
if [ -z "$DB" ]; then
    BASE=$(sh "$SCRIPT_DIR/_ai-context-paths.sh" --resolve "$PWD" 2>/dev/null)
    [ -n "$BASE" ] || { echo "store-query: ai-context base unresolved — Grep 直接走査（{base}/decisions/ {base}/docs/）へフォールバック" >&2; exit 1; }
    ROOT=$(dirname "$BASE")
    [ -f "$ROOT/.ai-context-store" ] || ROOT="$BASE"
    DB="$ROOT/.store-index.db"
fi
[ -f "$DB" ] || { echo "store-query: index not found ($DB) — Grep 直接走査（{base}/decisions/ {base}/docs/）へフォールバック" >&2; exit 1; }

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

# 0 件を黙って返さない(R8 実測: 多語 AND の無言 0 件で弱いモデルが検索を諦める)。
# AND が 0 件なら OR に自動緩和して再検索し、緩和したことを 1 行で明示する。
# それでも 0 件なら、次の一手(語を減らす・言い換える・Grep 併用)を必ず出力する。

_run_match() {  # $1 = FTS5 MATCH 式
    _m=$(printf '%s' "$1" | sed "s/'/''/g")
    sqlite3 -separator ' | ' "$DB" "SELECT project, relpath || '#' || heading,
        'L' || line_start || '-' || line_end,
        replace(snippet(sections, 7, '<<', '>>', '…', 20), char(10), ' ')
        FROM sections WHERE sections MATCH '$_m'$WHERE_PROJ
        ORDER BY bm25(sections) * (CASE doc_type WHEN 'decision' THEN 1.5 ELSE 1.0 END) LIMIT 8"
}
_run_like() {  # $1 = WHERE 条件(body LIKE ...)
    sqlite3 -separator ' | ' "$DB" "SELECT project, relpath || '#' || heading,
        'L' || line_start || '-' || line_end, substr(replace(body, char(10), ' '), 1, 120)
        FROM sections WHERE ($1)$WHERE_PROJ
        ORDER BY CASE doc_type WHEN 'decision' THEN 0 ELSE 1 END LIMIT 8"
}

RES=""
if [ "$short" = 0 ]; then
    AND_EXPR=""; OR_EXPR=""
    for t in "$@"; do
        esc=$(printf '%s' "$t" | sed 's/"/""/g')
        AND_EXPR="$AND_EXPR${AND_EXPR:+ AND }\"$esc\""
        OR_EXPR="$OR_EXPR${OR_EXPR:+ OR }\"$esc\""
    done
    RES=$(_run_match "$AND_EXPR")
    if [ -n "$RES" ]; then
        printf '%s\n' "$RES"
    elif [ $# -ge 2 ]; then
        RES=$(_run_match "$OR_EXPR")
        if [ -n "$RES" ]; then
            printf 'store-query: 0 hits (AND: %s) — OR に緩和した結果(いずれかの語を含む・要選別):\n' "$*"
            printf '%s\n' "$RES"
        fi
    fi
else
    W_AND=""; W_OR=""
    for t in "$@"; do
        esc=$(printf '%s' "$t" | sed "s/'/''/g")
        W_AND="$W_AND${W_AND:+ AND }body LIKE '%$esc%'"
        W_OR="$W_OR${W_OR:+ OR }body LIKE '%$esc%'"
    done
    RES=$(_run_like "$W_AND")
    if [ -n "$RES" ]; then
        printf '%s\n' "$RES"
    elif [ $# -ge 2 ]; then
        RES=$(_run_like "$W_OR")
        if [ -n "$RES" ]; then
            printf 'store-query: 0 hits (AND: %s) — OR に緩和した結果(いずれかの語を含む・要選別):\n' "$*"
            printf '%s\n' "$RES"
        fi
    fi
fi

if [ -z "$RES" ]; then
    printf 'store-query: 0 hits: %s — 語を減らす・別の言い方(同義語/英日)に変える・Grep 併用を検討(3 文字以上の語が最も効く)\n' "$*"
fi
