#!/bin/sh
# test-knowledge-draft-review.sh — knowledge-draft-review.sh の合成テスト
#
# 検証:
#   1. drafts < 閾値 → 何も出さない（exit 0）
#   2. drafts >= 閾値 → 1 回提示（件数 + /ai-context knowledge 誘導）し exit 0
#   3. once ガード: 同一 session_id の 2 回目は提示しない
#   4. 閾値は BANTO_DRAFT_REVIEW_MIN で可変
#   5. fail-open: drafts dir 不在 → 静かに exit 0
#   6. fail-open: jq 不在環境 → exit 0（no-op）。jq 必須環境は注記のみ
#
# 隔離: 合成 HOME + 合成 store root（AI_CONTEXT_STORE_ROOT）+ 合成 TMPDIR（once marker）。
#   実 ~/.claude / 実 store には一切触れない。
# POSIX `VAR=val func` の env leak を避けるため、hook 起動は run_hook 関数（外側 env を汚さない）。
set -u

DIR=$(cd "$(dirname "$0")/.." && pwd)
HOOK="$DIR/hooks/knowledge-draft-review.sh"

command -v jq  >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not found"; exit 0; }

# 外側に漏れている可能性のある上書きを掃除（テストの決定性）。
unset CLAUDE_PLUGIN_ROOT AI_CONTEXT_MAPPING AI_CONTEXT_STORE_ROOT BANTO_IGNORE_FILE BANTO_DRAFT_REVIEW_MIN 2>/dev/null || true

TMP=$(mktemp -d "${TMPDIR:-/tmp}/draft-review.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME/.claude" "$TMP/tmp"
STORE="$FAKE_HOME/ai-context-store"

# 登録済み repo + store project dir を用意（resolver が hit するよう mapping を書く）。
REPO="$TMP/proj/myrepo"
mkdir -p "$REPO"
git -C "$REPO" init -q
REPO_TOP=$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null)
PROJ="$STORE/myrepo"
DRAFTS="$PROJ/docs/knowledges/drafts"
mkdir -p "$DRAFTS" "$STORE"
[ -f "$STORE/.ai-context-store" ] || touch "$STORE/.ai-context-store"
cat > "$STORE/.mapping.json" <<MAP
{
  "version": 2,
  "store_root": "$STORE",
  "projects": { "$REPO_TOP": { "project": "myrepo" } }
}
MAP

fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

# hook を合成 HOME / store root / TMPDIR で起動（外側 env を汚さない subshell 実行）。
run_hook() { # payload [extra KEY=VAL ...]
    _pl="$1"; shift
    printf '%s' "$_pl" | env HOME="$FAKE_HOME" TMPDIR="$TMP/tmp" \
        AI_CONTEXT_STORE_ROOT="$STORE" AI_CONTEXT_MAPPING="$STORE/.mapping.json" \
        "$@" sh "$HOOK" 2>/dev/null
}

mk_drafts() { # N : drafts/ に N 件の *.md を作る（既存は消す）
    rm -f "$DRAFTS"/*.md 2>/dev/null
    _i=1
    while [ "$_i" -le "$1" ]; do
        printf '# draft %d\n' "$_i" > "$DRAFTS/d$_i.md"
        _i=$((_i + 1))
    done
}

# === 1. drafts < 閾値（既定 10）→ 何も出さない ===
mk_drafts 3
OUT=$(run_hook "{\"cwd\":\"$REPO\",\"session_id\":\"s-below\"}")
[ -z "$OUT" ] && ok "below default threshold: silent" || bad "below threshold: emitted output ($OUT)"

# === 2. drafts >= 閾値（10）→ 1 回提示 ===
mk_drafts 10
OUT=$(run_hook "{\"cwd\":\"$REPO\",\"session_id\":\"s-at\"}")
case "$OUT" in
    *"10"*"/ai-context knowledge"*) ok "at threshold: prompt with count + knowledge route" ;;
    *) bad "at threshold: prompt missing/incomplete ($OUT)" ;;
esac

# === 3. once ガード: 同一 session_id の 2 回目は黙る ===
OUT2=$(run_hook "{\"cwd\":\"$REPO\",\"session_id\":\"s-at\"}")
[ -z "$OUT2" ] && ok "once-guard: same session does not re-prompt" || bad "once-guard: re-prompted ($OUT2)"

# === 4. 閾値は env で可変（BANTO_DRAFT_REVIEW_MIN=3 → 3 件で提示） ===
mk_drafts 3
OUT=$(run_hook "{\"cwd\":\"$REPO\",\"session_id\":\"s-env\"}" BANTO_DRAFT_REVIEW_MIN=3)
case "$OUT" in
    *"3"*"/ai-context knowledge"*) ok "env threshold: BANTO_DRAFT_REVIEW_MIN=3 triggers at 3" ;;
    *) bad "env threshold: did not trigger at lowered min ($OUT)" ;;
esac

# === 5. fail-open: drafts dir 不在 → 静かに exit 0 ===
rm -rf "$DRAFTS"
OUT=$(run_hook "{\"cwd\":\"$REPO\",\"session_id\":\"s-nodir\"}")
rc=$?
[ -z "$OUT" ] && [ "$rc" -eq 0 ] && ok "fail-open: no drafts dir is silent, exit 0" || bad "fail-open: drafts dir absent not handled (rc=$rc out=$OUT)"

# === 6. fail-open: jq 不在をシミュレート（jq の無い最小 PATH で起動） ===
# sh だけ見つかり jq は見つからない PATH を用意（env -i + PATH="" だと sh 自体が見つからず
# env が 127 で死ぬため、sh を含む最小 bin dir を作る）。hook 冒頭の command -v jq で exit 0 の想定。
NOJQ_BIN="$TMP/nojq-bin"
mkdir -p "$NOJQ_BIN"
ln -s "$(command -v sh)" "$NOJQ_BIN/sh" 2>/dev/null || cp "$(command -v sh)" "$NOJQ_BIN/sh"
mkdir -p "$PROJ/docs/knowledges/drafts"
mk_drafts 10
printf '%s' "{\"cwd\":\"$REPO\",\"session_id\":\"s-nojq\"}" | \
    env -i HOME="$FAKE_HOME" TMPDIR="$TMP/tmp" PATH="$NOJQ_BIN" \
    AI_CONTEXT_STORE_ROOT="$STORE" sh "$HOOK" >/dev/null 2>&1
[ $? -eq 0 ] && ok "fail-open: no jq -> exit 0 (no-op)" || bad "fail-open: no-jq path did not exit 0"

[ "$fail" -eq 0 ] && echo "ALL GREEN"
exit "$fail"
