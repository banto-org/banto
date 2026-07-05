#!/bin/sh
# model-claim-guard.sh — Stop hook. Research analog of verify-claim-guard for model-lab.
#
# Blocks a final response that claims a model RESULT or PAPER is done / published while
# either (B) the latest eval state is RED, or (C) the claim ledger (BANTO_LEDGER) still
# holds non-"verified" entries. Narrow + deterministic; fires once per stop.
#
# fail-open: jq absent / no transcript / no result claim → exit 0.
set -u

INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0
[ "$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ] && exit 0

TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
{ [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; } && exit 0
TAIL=$(tail -80 "$TRANSCRIPT" 2>/dev/null)
[ -z "$TAIL" ] && exit 0

LAST_ASSISTANT=$(printf '%s\n' "$TAIL" | jq -R -s '
    [split("\n")[] | select(length > 0) | (fromjson? // empty)]
    | map(select(.type == "assistant")) | (.[-1] // {})
    | .message.content
    | if type == "array" then (map(select(.type == "text") | .text) | join(" ")) else (. // "") end
' 2>/dev/null)
[ -z "$LAST_ASSISTANT" ] && exit 0

# (A) a research RESULT / PAPER completion or publication claim.
#     強い主張（論文完成 / SOTA / 新記録）は単独で発火。汎用の公開・提出・達成動詞は
#     研究名詞（論文 / eval / HF / arxiv 等）が同じ最終応答に共起する場合のみ発火する —
#     旧実装は「PR を公開しました」等のプラグイン運用報告にも反応する誤検知源だった。
CLAIM='論文.*(完成|完了|書け?た|ドラフト)|paper.*(done|ready|complete|written)|SOTA|state-of-the-art|新記録'
PUB='(公開|提出|達成)しました|publish(ed)?|submitted'
NOUN='論文|paper|arxiv|checkpoint|重み|weights|eval|ベンチ|benchmark|HF|Hugging ?Face|hf\.co|蒸留|distill|pruning|fine-?tune|事前学習|pretrain'
if ! printf '%s' "$LAST_ASSISTANT" | grep -iqE "$CLAIM"; then
    printf '%s' "$LAST_ASSISTANT" | grep -iqE "$PUB" || exit 0
    printf '%s' "$LAST_ASSISTANT" | grep -iqE "$NOUN" || exit 0
fi

# (B) latest eval state RED → block (mirror verify-claim-guard's verify-last)
#     4 時間より古い状態は無視 — 過去の model-lab 走行の残骸 RED が無関係な
#     セッションを塞ぐ誤検知を防ぐ。
ESTATE_DIR="${ODD_STATE_DIR:-$HOME/.cache/banto}"
ESTATE=$(ls -t "$ESTATE_DIR"/eval-last-* 2>/dev/null | head -1)
if [ -n "$ESTATE" ] && [ -z "$(find "$ESTATE" -mmin +240 2>/dev/null)" ] \
   && head -1 "$ESTATE" 2>/dev/null | grep -q '^red'; then
    cat >&2 <<'MSG'
⚠ model-claim-guard: the response claims a result/paper is done, but the latest eval is RED.
Re-run eval (scripts/eval-stats.sh) until GREEN, and confirm each claim is backed, before claiming done.
- If this red is stale / unrelated → finishing as-is is fine (fires once per stop).
MSG
    exit 2
fi

# (C) claim ledger still has non-verified entries → block
LEDGER="${BANTO_LEDGER:-}"
if [ -n "$LEDGER" ] && [ -f "$LEDGER" ]; then
    UNV=$(jq -r 'select((.status // "") != "verified") | .claim // .run_id // "entry"' "$LEDGER" 2>/dev/null | head -3)
    if [ -n "$UNV" ]; then
        { echo "⚠ model-claim-guard: the claim ledger ($LEDGER) still has non-verified entries:"
          printf '%s\n' "$UNV" | sed 's/^/  - /'
          echo "  Each paper/result claim needs a 'verified' entry (run_id + seeds + CI). Verify or drop it."
        } >&2
        exit 2
    fi
fi

exit 0
