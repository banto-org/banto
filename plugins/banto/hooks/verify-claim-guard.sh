#!/bin/sh
# Stop hook — Verify-before-claim guard
# 「最終応答の完了断定」と「直近 tool 出力の error / truncation / 中断」が同居したら
# exit 2 で 1 回だけ再 verify を促す。誤読5回（truncate 出力の早合点 / error を無視した
# 完了報告）の機械的に取れるスライスだけを決定論で捕捉する narrow なガード。
#
# 設計方針:
#   - fail-open: 判定材料が無い / jq 不在 / パース不能 → 何もしない (exit 0)
#   - 1 stop に 1 回だけ: stop_hook_active で再発火を防ぎ無限ループを回避
#   - 両条件 (A 完了断定 ∧ B 直近 error) が揃った時のみ exit 2（block + stderr を Claude に提示）

INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

# 既に本ガード起因で継続中なら二度と発火しない（ループ回避）
[ "$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ] && exit 0

TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
{ [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; } && exit 0

# 直近の活動だけを対象（現ターン近傍）。partial line は fromjson? で読み飛ばす。
TAIL=$(tail -80 "$TRANSCRIPT" 2>/dev/null)
[ -z "$TAIL" ] && exit 0

# (A) 最終 assistant テキストに「完了 / 成功」等の断定があるか
LAST_ASSISTANT=$(printf '%s\n' "$TAIL" | jq -R -s '
    [split("\n")[] | select(length > 0) | (fromjson? // empty)]
    | map(select(.type == "assistant"))
    | (.[-1] // {})
    | .message.content
    | if type == "array" then (map(select(.type == "text") | .text) | join(" "))
      else (. // "") end
' 2>/dev/null)
[ -z "$LAST_ASSISTANT" ] && exit 0

CLAIM='完了|完成|修正しました|修正済|実装しました|実装済|対応しました|できました|成功しました|問題ありませ|正常に動作|動作確認済|テストが?(通|パス|成功)|all tests? pass|tests? pass|fixed it|completed|successfully'
printf '%s' "$LAST_ASSISTANT" | grep -iqE "$CLAIM" || exit 0

# (B1) build-and-verify: 直近のフル verify（verify-run.sh）が RED なら、green になる前の
#      完了断定を止める。最新の verify-last-* を mtime で辿る（session_id 不一致に強い）。
#      4 時間より古い状態は無視する — 別作業の残骸 RED が現セッションを塞ぐ誤検知を防ぐ。
VSTATE_DIR="${ODD_STATE_DIR:-$HOME/.cache/banto}"
VSTATE=$(ls -t "$VSTATE_DIR"/verify-last-* 2>/dev/null | head -1)
if [ -n "$VSTATE" ] && [ -z "$(find "$VSTATE" -mmin +240 2>/dev/null)" ] \
   && head -1 "$VSTATE" 2>/dev/null | grep -q '^red'; then
    cat >&2 <<'MSG'
⚠ verify-before-claim: the final response claims completion, but the last full verify
(verify-run) is RED. Fix the failure and re-run verify-run until it is GREEN before claiming done.
- If this red is stale / unrelated → finishing as-is is fine (this warning fires only once per stop).
MSG
    exit 2
fi

# (B2) 直近 tool 出力に未解決の error があるか — jq で tool_result の is_error フラグを
#     構造的に判定する。旧実装の raw grep は、ファイル内容に含まれる "fatal:" や
#     "No such file or directory"（このリポジトリの hook ソースに常在）にも反応する
#     主要な誤検知源だったため廃止。末尾 3 件の tool_result に限定する — それより前の
#     error は後続の成功呼び出しで解消済みとみなす（探索的な失敗コマンドは正常な作業）。
RECENT_ERR=$(printf '%s\n' "$TAIL" | jq -R -s '
    [split("\n")[] | select(length > 0) | (fromjson? // empty)]
    | map(select(.type == "user") | .message.content
          | if type == "array" then .[] else empty end
          | select(.type? == "tool_result"))
    | .[-3:]
    | map(select(.is_error == true))
    | length
' 2>/dev/null)
[ "${RECENT_ERR:-0}" -gt 0 ] 2>/dev/null || exit 0

# A ∧ B 成立 → 断定の前に実体確認を促す
cat >&2 <<'MSG'
⚠ verify-before-claim: the final response claims completion/success, but recent tool output
shows traces of an error / truncation / interruption. Before claiming, actually verify that
tool result (did you miss a failure? was the output cut off?).

- If you missed a failure → fix it, re-run, then report completion
- If it was already resolved and this is a false positive → finishing as-is is fine (this warning fires only once per stop)
MSG
exit 2
