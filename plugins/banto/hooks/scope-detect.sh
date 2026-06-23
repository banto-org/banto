#!/bin/sh
# scope-detect.sh — UserPromptSubmit: 大規模作業の兆候を検出して concept/spec + worktree を提案する
#
# 「実装して」「作って」「リファクタ」等 + 規模シグナル（複数ファイル / 新機能 / Phase）を検出したら、
# concept/spec の発動と worktree 作成を**提案**する（強制発火はしない）。
# 決定: spec 規模検出と worktree を連動（decisions/2026-05-29_001 確定事項 #13/#14）。
# v5.20.0: design-first→spec 改名 + concept(思想)を上流に追加。
#
# exit 0 で常に終了（ブロックしない）。stdout がコンテキストに追加される。
# 1 セッション 1 回だけ提案（tmp フラグで抑止）。
# POSIX互換: macOS / Linux / WSL

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0
[ -z "$CWD" ] && exit 0

# 実装系の動詞（これが無ければ対象外）
IMPL_VERBS='(実装して|作って|作成して|開発して|構築して|リファクタ|refactor|build |implement|create )'
echo "$PROMPT" | grep -qiE "$IMPL_VERBS" || exit 0

# 規模シグナル（いずれか該当で「大規模の可能性」）
SCALE_SIGNALS='(機能|feature|複数|いくつか|全部|まとめて|システム|アーキ|architecture|新しい|新規|move|migrat|モジュール|エンドポイント|画面|ページ|コンポーネント群|一括|Phase|フェーズ)'
echo "$PROMPT" | grep -qiE "$SCALE_SIGNALS" || exit 0

# 明確に小規模を示す語があれば抑止（typo / 1 行 / 1 ファイル）
SMALL_SIGNALS='(typo|タイポ|1 ?行|一行|1 ?ファイル|一ファイル|誤字|リネームだけ|コメントだけ|文言)'
echo "$PROMPT" | grep -qiE "$SMALL_SIGNALS" && exit 0

# セッション単位の発火抑制（CWD ハッシュで代用）
if [ -z "$SESSION_ID" ]; then
    SESSION_ID=$(echo -n "$CWD" | (md5sum 2>/dev/null || md5 2>/dev/null || cksum) | cut -d' ' -f1)
fi
FLAG="${TMPDIR:-/tmp}/scope-detect-${SESSION_ID}.fired"
[ -f "$FLAG" ] && exit 0
touch "$FLAG"

# 現在 worktree か（既に feature worktree 上なら worktree 提案は省く）
BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null)
ON_MAIN=0
case "$BRANCH" in main|master) ON_MAIN=1 ;; esac

cat <<EOF
[Scope Detect] Detected signs of large-scale work (multiple files / new feature / refactor etc.).
Consider the following before starting (decision: spec scale-detection is linked with worktrees):

1. **Run spec first** → produce spec/plan/tasks before implementing
   - Saying "design only first" or "write a spec" triggers the spec skill
   - For a new product/feature, run the concept skill before that ("solidify the philosophy")
EOF

if [ "$ON_MAIN" = "1" ]; then
    cat <<EOF
2. **Create a worktree** (currently on the ${BRANCH} branch) → isolate large work
   - e.g. \`git worktree add -b feat/<topic> ../<repo>-<topic> ${BRANCH}\`
   - or use the ws skill / \`claude -w <name>\`
EOF
elif [ -z "$BRANCH" ]; then
    # 非 git ディレクトリ（旧実装は「既に \`\` ブランチ上」と空名を表示していた）
    echo "2. This directory is not under git, so the worktree suggestion is skipped."
else
    echo "2. Already on the \`${BRANCH}\` branch, so continuing here is fine."
fi

echo ""
echo "(If this is actually a small change, ignore this suggestion and proceed directly)"
exit 0
