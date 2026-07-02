#!/bin/sh
# typecheck.sh — PostToolUse(Write|Edit) フック
# 変更ファイルの型エラーだけを高速チェック
# 改善: tsc全体実行を避け、変更ファイルのエラーのみ抽出

INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)

[ -z "$CWD" ] || [ -z "$FILE_PATH" ] && exit 0
cd "$CWD" 2>/dev/null || exit 0

EXT="${FILE_PATH##*.}"

# macOS 標準に timeout が無い（coreutils の gtimeout のみの環境あり）。
# 不在のまま `timeout 20 ...` を呼ぶと command not found → ERRORS 空 → 型チェックが黙って無効化されるため、
# 実在する方を使い、どちらも無ければタイムアウトなしで実行する
TIMEOUT_BIN=$(command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null)

case "$EXT" in
  ts|tsx)
    [ ! -f "tsconfig.json" ] && exit 0
    # tsc --noEmit の結果から対象ファイルのエラーだけ抽出
    # タイムアウト20秒（大規模プロジェクト対策）
    ERRORS=$(${TIMEOUT_BIN:+$TIMEOUT_BIN 20} npx tsc --noEmit --pretty false 2>&1 | grep -F "$(basename "$FILE_PATH")" | head -5)
    if [ -n "$ERRORS" ]; then
      echo "[Harness typecheck] Type errors:" >&2
      echo "$ERRORS" >&2
      exit 2
    fi
    ;;
  py)
    # pyright があれば対象ファイルのみチェック（高速）
    if command -v pyright >/dev/null 2>&1; then
      ERRORS=$(${TIMEOUT_BIN:+$TIMEOUT_BIN 15} pyright "$FILE_PATH" 2>&1 | grep -E "error:" | head -5)
      if [ -n "$ERRORS" ]; then
        echo "[Harness typecheck] Type errors:" >&2
        echo "$ERRORS" >&2
        exit 2
      fi
    fi
    ;;
esac

exit 0
