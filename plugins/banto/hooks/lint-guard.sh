#!/bin/sh
# lint-guard.sh — PreToolUse(Write|Edit) フック
# 書き込み先がロックファイルやビルド成果物でないかチェックする
# exit 0 → 許可, exit 2 → ブロック

INPUT=$(cat)
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)

[ -z "$FILE_PATH" ] && exit 0

BASENAME=$(basename "$FILE_PATH")

# 自動生成ファイルへの書き込みをブロック
case "$BASENAME" in
  package-lock.json|yarn.lock|pnpm-lock.yaml|bun.lock|bun.lockb|Gemfile.lock|poetry.lock|Cargo.lock|uv.lock|composer.lock|go.sum)
    echo "[Harness] Direct edits to the lockfile ${BASENAME} are discouraged. Update it via the package manager." >&2
    exit 2
    ;;
  *.min.js|*.min.css|*.bundle.js|*.chunk.js)
    echo "[Harness] The build artifact ${BASENAME} cannot be edited directly. Edit the source files instead." >&2
    exit 2
    ;;
esac

# dist/, build/, node_modules/ への書き込みをブロック
case "$FILE_PATH" in
  */dist/*|*/build/*|*/node_modules/*|*/.next/*|*/target/*|*/__pycache__/*)
    echo "[Harness] Build output directories cannot be edited directly. Edit the source files instead." >&2
    exit 2
    ;;
esac

exit 0
