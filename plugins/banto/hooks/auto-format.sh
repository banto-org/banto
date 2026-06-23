#!/bin/sh
# auto-format.sh — PostToolUse(Write|Edit) フック
# ファイル書き込み/編集後に自動フォーマットを実行する
# Claude Codeパターン: 品質はプロンプトで、整形は外部ツールで

INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)

[ -z "$CWD" ] || [ -z "$FILE_PATH" ] && exit 0

# ファイルの拡張子を取得
EXT="${FILE_PATH##*.}"

cd "$CWD" 2>/dev/null || exit 0

# biome があれば使う（JS/TS系）
if [ -f "biome.json" ] || [ -f "biome.jsonc" ]; then
  case "$EXT" in
    ts|tsx|js|jsx|json|css)
      npx biome format --write "$FILE_PATH" 2>/dev/null
      exit 0
      ;;
  esac
fi

# prettier があれば使う
if [ -f ".prettierrc" ] || [ -f ".prettierrc.json" ] || [ -f ".prettierrc.js" ] || [ -f "prettier.config.js" ] || [ -f "prettier.config.mjs" ]; then
  case "$EXT" in
    ts|tsx|js|jsx|json|css|scss|md|yaml|yml|html|vue|svelte)
      npx prettier --write "$FILE_PATH" 2>/dev/null
      exit 0
      ;;
  esac
fi

# ruff があれば使う（Python）
if [ -f "pyproject.toml" ] && command -v ruff >/dev/null 2>&1; then
  case "$EXT" in
    py)
      ruff format "$FILE_PATH" 2>/dev/null
      exit 0
      ;;
  esac
fi

exit 0
