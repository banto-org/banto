#!/bin/sh
# test-verify-detect.sh — hermetic fixtures for hooks/verify-detect.sh
# (build-and-verify loop, Phase 1). Builds throwaway project shapes and asserts the
# detected build / test / api-smoke commands and the runner token. POSIX sh.
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DETECT="$SCRIPT_DIR/../hooks/verify-detect.sh"
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "  ok: $1"; }
no() { fail=$((fail + 1)); echo "  NO: $1"; }

# expect <dir> <KEY> <expected> <label>
expect() {
    got=$(sh "$DETECT" "$1" 2>/dev/null | grep "^$2=" | cut -d= -f2-)
    if [ "$got" = "$3" ]; then ok "$4 ($2=[$3])"; else no "$4: $2 expected [$3] got [$got]"; fi
}
# expect_runner <dir> <expected>
expect_runner() {
    got=$(sh "$DETECT" --runner "$1" 2>/dev/null)
    if [ "$got" = "$2" ]; then ok "runner($1 basename) = [$2]"; else no "runner expected [$2] got [$got]"; fi
}

FIX=$(mktemp -d)
trap 'rm -rf "$FIX"' EXIT

# --- node with build/test/smoke scripts ---
mkdir -p "$FIX/node"
printf '%s\n' '{"scripts":{"build":"tsc","test":"vitest run","smoke":"node smoke.js"}}' > "$FIX/node/package.json"
expect "$FIX/node" BUILD_CMD "npm run build" "node build script"
expect "$FIX/node" TEST_CMD "npm test" "node test script"
expect "$FIX/node" API_SMOKE_CMD "npm run smoke" "node smoke script"

# --- node without a smoke-ish script -> empty api ---
mkdir -p "$FIX/node-nosmoke"
printf '%s\n' '{"scripts":{"build":"tsc","test":"vitest run"}}' > "$FIX/node-nosmoke/package.json"
expect "$FIX/node-nosmoke" API_SMOKE_CMD "" "node no-smoke -> empty api"

# --- node with test:api -> api smoke ---
mkdir -p "$FIX/node-api"
printf '%s\n' '{"scripts":{"test:api":"jest api"}}' > "$FIX/node-api/package.json"
expect "$FIX/node-api" API_SMOKE_CMD "npm run test:api" "node test:api -> api smoke"

# --- rust ---
mkdir -p "$FIX/rust"; printf '[package]\n' > "$FIX/rust/Cargo.toml"
expect "$FIX/rust" BUILD_CMD "cargo build" "rust build"
expect "$FIX/rust" TEST_CMD "cargo test" "rust test"
expect "$FIX/rust" API_SMOKE_CMD "" "rust -> empty api"
expect_runner "$FIX/rust" "cargo"

# --- go ---
mkdir -p "$FIX/go"; printf 'module x\n' > "$FIX/go/go.mod"
expect "$FIX/go" BUILD_CMD "go build ./..." "go build"
expect "$FIX/go" TEST_CMD "go test ./..." "go test"
expect_runner "$FIX/go" "go"

# --- python ---
mkdir -p "$FIX/py"; printf '[project]\n' > "$FIX/py/pyproject.toml"
expect "$FIX/py" TEST_CMD "pytest" "py test"
expect_runner "$FIX/py" "pytest"

# --- vitest config (no scripts) -> runner + full test cmd ---
mkdir -p "$FIX/vitest"; printf 'export default {}\n' > "$FIX/vitest/vitest.config.ts"
expect "$FIX/vitest" TEST_CMD "npx vitest run" "vitest config -> full test"
expect_runner "$FIX/vitest" "vitest"

# --- tsconfig-only build fallback ---
mkdir -p "$FIX/ts"; printf '{}\n' > "$FIX/ts/tsconfig.json"
expect "$FIX/ts" BUILD_CMD "npx tsc --noEmit" "tsconfig -> build fallback"

# --- bare project: everything empty ---
mkdir -p "$FIX/bare"
expect "$FIX/bare" BUILD_CMD "" "bare -> empty build"
expect "$FIX/bare" TEST_CMD "" "bare -> empty test"
expect "$FIX/bare" API_SMOKE_CMD "" "bare -> empty api"
expect_runner "$FIX/bare" ""

echo "verify-detect tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
