#!/bin/sh
# auto-test.sh — PostToolUse(Write|Edit) フック
# ファイル変更後に関連テストを自動検出・実行する
# 改善: プロジェクト設定からテストランナーを検出、幅広いテストファイル配置に対応

INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)

# このスクリプトの場所を cd 前に絶対解決（相対起動でも verify-detect を見つけられるように）
SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

[ -z "$CWD" ] || [ -z "$FILE_PATH" ] && exit 0

# consecutive test-failure counter (read by odd-gate.sh as a circuit breaker)
TF_DIR="${ODD_STATE_DIR:-$HOME/.cache/banto}"
TF_FILE="$TF_DIR/test-failures-${SESSION_ID:-nosession}"
_tf_bump() { mkdir -p "$TF_DIR" 2>/dev/null; _n=$(cat "$TF_FILE" 2>/dev/null); case "$_n" in ''|*[!0-9]*) _n=0;; esac; printf '%s' "$((_n + 1))" > "$TF_FILE" 2>/dev/null; }
_tf_reset() { mkdir -p "$TF_DIR" 2>/dev/null; printf '0' > "$TF_FILE" 2>/dev/null; }
cd "$CWD" 2>/dev/null || exit 0

# テスト対象外の拡張子
case "$FILE_PATH" in
  *.md|*.json|*.yaml|*.yml|*.toml|*.css|*.scss|*.html|*.svg|*.png|*.jpg|*.lock|*.lockb)
    exit 0 ;;
esac

# テストファイル自体の変更はスキップ（無限ループ防止）
case "$FILE_PATH" in
  *.test.*|*.spec.*|*_test.*|*_spec.*|test_*|*/__tests__/*|*/tests/test_*)
    exit 0 ;;
esac

BASENAME=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//')
DIR=$(dirname "$FILE_PATH")
EXT="${FILE_PATH##*.}"

# 関連テストファイルを幅広く探す
TEST_FILE=""
for pattern in \
  "${DIR}/${BASENAME}.test.${EXT}" \
  "${DIR}/${BASENAME}.spec.${EXT}" \
  "${DIR}/${BASENAME}_test.${EXT}" \
  "${DIR}/__tests__/${BASENAME}.test.${EXT}" \
  "${DIR}/__tests__/${BASENAME}.spec.${EXT}" \
  "${DIR}/../__tests__/${BASENAME}.test.${EXT}" \
  "${DIR}/../tests/${BASENAME}.test.${EXT}" \
  "${DIR}/tests/test_${BASENAME}.py" \
  "${DIR}/tests/${BASENAME}_test.py" \
  "${DIR}/../tests/test_${BASENAME}.py" \
  "tests/test_${BASENAME}.py" \
  "test/${BASENAME}_test.go"
do
  if [ -f "$pattern" ]; then
    TEST_FILE="$pattern"
    break
  fi
done

# パターンで見つからなければ find で探す（1秒タイムアウト）
if [ -z "$TEST_FILE" ]; then
  TEST_FILE=$(timeout 1 find . -maxdepth 5 \( \
    -name "${BASENAME}.test.*" -o \
    -name "${BASENAME}.spec.*" -o \
    -name "${BASENAME}_test.*" -o \
    -name "test_${BASENAME}.*" \
  \) -not -path "*/node_modules/*" -not -path "*/.git/*" -print -quit 2>/dev/null)
fi

[ -z "$TEST_FILE" ] && exit 0

# テストランナーを検出して実行（検出ロジックは verify-detect.sh を単一正本として共有）
# 注: `RESULT=$(runner | tail -5)` だと $? が tail の exit code になり失敗を観測できない
# （block と失敗カウンタが永久に発火しない既存バグ）。tail は表示時に行う。
RUNNER=$(sh "$SELF_DIR/verify-detect.sh" --runner "$CWD" 2>/dev/null)
case "$RUNNER" in
  vitest) RESULT=$(npx vitest run "$TEST_FILE" --reporter=dot 2>&1) ;;
  jest)   RESULT=$(npx jest "$TEST_FILE" --no-coverage 2>&1) ;;
  pytest) command -v pytest >/dev/null 2>&1 || exit 0; RESULT=$(pytest "$TEST_FILE" -q --tb=line 2>&1) ;;
  cargo)  RESULT=$(cargo test --quiet 2>&1) ;;
  go)     TEST_DIR=$(dirname "$TEST_FILE"); RESULT=$(go test "./${TEST_DIR}/..." 2>&1) ;;
  *)      exit 0 ;;
esac

EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  _tf_bump
  echo "[Harness test] ${TEST_FILE} failed:" >&2
  printf '%s\n' "$RESULT" | tail -5 >&2
  exit 2
fi

_tf_reset
echo "[Harness test] ${TEST_FILE} — PASS" >&2
exit 0
