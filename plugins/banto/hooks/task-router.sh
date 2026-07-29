#!/bin/sh
# task-router.sh — UserPromptSubmit: 実行可能な指示を検出し、tasks.md への投入 +
# WS 振り分けをメイン AI に促す（nudge のみ・block しない）。
#
# 検出: 実装系 or 調査系の動詞、または後回し/追加マーカー（また/とか/これも/後で 等）。
# メイン AI は「現 WS の tasks.md にタスクとして追記し、topic drift なら該当 WS を提案」する。
# 些末・その場完結・質問はメイン AI の判断で除外する（本 hook は判定を強制しない）。
#
# scope-detect.sh（大規模作業 → spec/worktree 提案・1 セッション 1 回）とは別レイヤー:
# こちらは「後回し/追加/調査を含む個々の指示 → tasks.md 投入」を per-prompt で促す。
# exit 0 で常に終了。stdout がコンテキストに追加される。
# POSIX互換: macOS / Linux / WSL

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0

# 明確に些末なら抑止（typo / 1 行 / コメントだけ）
SMALL='(typo|タイポ|1 ?行|一行|誤字|リネームだけ|コメントだけ|この行だけ)'
echo "$PROMPT" | grep -qiE "$SMALL" && exit 0

# 実行可能シグナル（実装系 or 調査系）
ACTION='(実装|作って|作成し|開発|構築|リファクタ|直して|修正し|やって|refactor|build |implement|create |fix |調べ|確認し|検討|調査|リサーチ|見直し|レビュー|research|investigate|review)'
# 後回し / 追加マーカー（単発の追加指示を拾う）
BATCH='(また|とか|これも|ついでに|後で|あとで|も入れ|も見たい|も検討|次のタスク|タスクに|todo|やっておいて|入れておいて)'

if echo "$PROMPT" | grep -qiE "$ACTION" || echo "$PROMPT" | grep -qiE "$BATCH"; then
    cat <<'EOF'
[Task Router] この指示にトラッキングすべき作業（実装系・調査系のいずれも対象）が含まれるなら、現在の WS の tasks.md に `- [ ] {簡潔なタスク}` として追記する（intent-first: モーダル確認で会話を割らず、追記したことを 1 行で伝える）。現在の WS スコープから外れているなら該当 WS への切替 / 新規を ws skill で提案する。質問・雑談・その場で完結する些末な編集はタスク化しない。
EOF
fi
exit 0
