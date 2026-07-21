#!/bin/sh
# ai-context-migration-status.sh — cross-project migration / registration status for `/ai-context doctor`.
#
# Read-only. Answers "what hasn't been migrated?" by listing projects that live only in the temporary
# local store (~/ai-context-local, GitHub-less) and have NOT been promoted to the central store:
#   • promotable  — local:!=true, i.e. an auto-created temp store awaiting `/ai-context bootstrap`
#   • pinned      — local:true,  i.e. intentionally local-only (bootstrap is a no-op there)
# Also flags whether the current repo still carries an un-migrated in-repo `.ai-context/`.
#
# Env overrides (tests): AI_CONTEXT_STORE_ROOT, AI_CONTEXT_LOCAL_ROOT. Arg $1 = cwd (default $PWD).
set -u

CWD=${1:-$PWD}
STORE_ROOT=${AI_CONTEXT_STORE_ROOT:-$HOME/ai-context-store}
LOCAL_ROOT=${AI_CONTEXT_LOCAL_ROOT:-$HOME/ai-context-local}
CENTRAL_MAP="$STORE_ROOT/.mapping.json"
LOCAL_MAP="$LOCAL_ROOT/.mapping.json"

command -v jq >/dev/null 2>&1 || { echo "移行ステータス: jq 不在のため skip"; exit 0; }

echo "== 移行ステータス（横断）=="

# Central-registered project paths (keys), used to exclude already-promoted repos.
CK='[]'
[ -f "$CENTRAL_MAP" ] && CK=$(jq -c '(.projects // {}) | keys' "$CENTRAL_MAP" 2>/dev/null || echo '[]')

# Count content (decisions + docs) under a local project dir, so the user knows which have real data.
_count() {  # $1 = project name
    d="$LOCAL_ROOT/$1"
    dec=$(find "$d/decisions" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    doc=$(find "$d/docs" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    echo "decisions:${dec:-0} docs:${doc:-0}"
}

if [ ! -f "$LOCAL_MAP" ]; then
    echo "  中央未昇格のローカルプロジェクトなし（$LOCAL_ROOT 未使用）"
else
    promotable=$(jq -r --argjson ck "$CK" '
      (.projects // {}) | to_entries[]
      | .key as $k
      | select(($ck | index($k)) == null)
      | select((.value.local // false) != true)
      | .value.project' "$LOCAL_MAP" 2>/dev/null)
    pinned=$(jq -r --argjson ck "$CK" '
      (.projects // {}) | to_entries[]
      | .key as $k
      | select(($ck | index($k)) == null)
      | select((.value.local // false) == true)
      | .value.project' "$LOCAL_MAP" 2>/dev/null)

    if [ -n "$promotable" ]; then
        echo "  ⤴ 中央未昇格・昇格候補（各 repo で「GitHub に上げたい」= /ai-context bootstrap）:"
        echo "$promotable" | while IFS= read -r p; do [ -n "$p" ] && echo "    - $p  ($(_count "$p"))"; done
    fi
    if [ -n "$pinned" ]; then
        echo "  📌 ローカル固定（local:true・意図的。昇格不要）:"
        echo "$pinned" | while IFS= read -r p; do [ -n "$p" ] && echo "    - $p"; done
    fi
    [ -z "$promotable" ] && [ -z "$pinned" ] && echo "  ✓ 中央未昇格のローカルプロジェクトなし"
fi

# Current repo: un-migrated in-repo .ai-context/ (auto-migration copies it at SessionStart; flag if pending).
TOP=$(cd "$CWD" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || echo "$CWD")
if [ -d "$TOP/.ai-context" ]; then
    echo "  ⚠ 現 repo に in-repo .ai-context/ が残存: セッション開始時に中央へ自動コピー（非破壊）されます。"
else
    echo "  ✓ 現 repo に in-repo .ai-context/ の残存なし"
fi
