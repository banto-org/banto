#!/bin/sh
# verify-detect.sh — detect a project's verify commands. Single source of truth shared by
# auto-test.sh (per-edit, --runner mode) and verify-run.sh (full verify, default mode).
# Pure file-based detection (never runs the project's tools) so it stays hermetic and
# environment-independent. API smoke is a package.json script (owner decision 2026-06-22, Q1).
#
# Modes:
#   verify-detect.sh <dir>           -> 3 lines: BUILD_CMD= / TEST_CMD= / API_SMOKE_CMD= (empty if none)
#   verify-detect.sh --runner <dir>  -> one token: vitest|jest|pytest|cargo|go (empty if none)
set -u

if [ "${1:-}" = "--runner" ]; then MODE=runner; DIR=${2:-.}; else MODE=cmds; DIR=${1:-.}; fi
if [ ! -d "$DIR" ]; then
    [ "$MODE" = runner ] && echo "" || printf 'BUILD_CMD=\nTEST_CMD=\nAPI_SMOKE_CMD=\n'
    exit 0
fi

PKG="$DIR/package.json"
SCRIPTS=""
if command -v jq >/dev/null 2>&1 && [ -f "$PKG" ]; then
    SCRIPTS=$(jq -r '.scripts // {} | keys[]' "$PKG" 2>/dev/null)
fi
_has() { printf '%s\n' "$SCRIPTS" | grep -qx "$1"; }

# runner detection (config-file based) — shared so per-edit auto-test and full verify agree
RUNNER=""
if   ls "$DIR"/vitest.config.* >/dev/null 2>&1; then RUNNER=vitest
elif ls "$DIR"/jest.config.*   >/dev/null 2>&1; then RUNNER=jest
elif [ -f "$DIR/pyproject.toml" ]; then RUNNER=pytest
elif [ -f "$DIR/Cargo.toml" ]; then RUNNER=cargo
elif [ -f "$DIR/go.mod" ]; then RUNNER=go
fi

if [ "$MODE" = runner ]; then echo "$RUNNER"; exit 0; fi

# --- BUILD ---
BUILD_CMD=""
if _has build; then BUILD_CMD="npm run build"
elif [ -f "$DIR/tsconfig.json" ]; then BUILD_CMD="npx tsc --noEmit"
elif [ -f "$DIR/Cargo.toml" ]; then BUILD_CMD="cargo build"
elif [ -f "$DIR/go.mod" ]; then BUILD_CMD="go build ./..."
fi

# --- TEST (full suite): explicit npm test wins, else map the detected runner ---
TEST_CMD=""
if _has test; then TEST_CMD="npm test"
elif [ "$RUNNER" = vitest ]; then TEST_CMD="npx vitest run"
elif [ "$RUNNER" = jest ]; then TEST_CMD="npx jest"
elif [ "$RUNNER" = pytest ]; then TEST_CMD="pytest"
elif [ "$RUNNER" = cargo ]; then TEST_CMD="cargo test"
elif [ "$RUNNER" = go ]; then TEST_CMD="go test ./..."
fi

# --- API SMOKE: package.json script (Q1 priority order) ---
API_SMOKE_CMD=""
for s in smoke smoke-test test:api test:integration; do
    if _has "$s"; then API_SMOKE_CMD="npm run $s"; break; fi
done

printf 'BUILD_CMD=%s\nTEST_CMD=%s\nAPI_SMOKE_CMD=%s\n' "$BUILD_CMD" "$TEST_CMD" "$API_SMOKE_CMD"
