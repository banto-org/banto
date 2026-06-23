#!/bin/sh
# test-verify-run.sh — hermetic tests for hooks/verify-run.sh via the BANTO_VERIFY_CMDS_FILE
# seam (no external runners needed: build/test/api are plain `true`/`false`). POSIX sh.
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RUN="$SCRIPT_DIR/../hooks/verify-run.sh"
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "  ok: $1"; }
no() { fail=$((fail + 1)); echo "  NO: $1"; }

FIX=$(mktemp -d); trap 'rm -rf "$FIX"' EXIT
export ODD_STATE_DIR="$FIX/state"
export BANTO_SESSION_ID="t"
VS="$FIX/state/verify-last-t"; TF="$FIX/state/test-failures-t"

run() { # <build> <test> <api>
    printf 'BUILD_CMD=%s\nTEST_CMD=%s\nAPI_SMOKE_CMD=%s\n' "$1" "$2" "$3" > "$FIX/cmds"
    rm -f "$VS" "$TF"
    BANTO_VERIFY_CMDS_FILE="$FIX/cmds" sh "$RUN" "$FIX" >/dev/null 2>&1; EC=$?
}

# all green -> exit 0, state green, TF 0
run "true" "true" "true"
[ "$EC" -eq 0 ] && ok "all-pass exit 0" || no "all-pass exit ($EC)"
[ "$(cat "$VS" 2>/dev/null)" = "green" ] && ok "all-pass state green" || no "all-pass state [$(cat "$VS" 2>/dev/null)]"
[ "$(cat "$TF" 2>/dev/null)" = "0" ] && ok "all-pass TF reset 0" || no "all-pass TF [$(cat "$TF" 2>/dev/null)]"

# test fails -> exit 2, state red, TF bumped
run "true" "false" ""
[ "$EC" -eq 2 ] && ok "test-fail exit 2" || no "test-fail exit ($EC)"
case "$(cat "$VS" 2>/dev/null)" in red:*test*) ok "test-fail state red:test";; *) no "test-fail state [$(cat "$VS" 2>/dev/null)]";; esac
[ "$(cat "$TF" 2>/dev/null)" = "1" ] && ok "test-fail TF bumped to 1" || no "test-fail TF [$(cat "$TF" 2>/dev/null)]"

# build fails -> exit 2
run "false" "true" "true"
[ "$EC" -eq 2 ] && ok "build-fail exit 2" || no "build-fail exit ($EC)"

# api smoke fails -> exit 2
run "true" "true" "false"
[ "$EC" -eq 2 ] && ok "api-fail exit 2" || no "api-fail exit ($EC)"
case "$(cat "$VS" 2>/dev/null)" in *api-smoke*) ok "api-fail names api-smoke";; *) no "api-fail state [$(cat "$VS" 2>/dev/null)]";; esac

# nothing configured -> green no-op, exit 0
run "" "" ""
[ "$EC" -eq 0 ] && ok "no-cmds exit 0 (no-op)" || no "no-cmds exit ($EC)"

# only test configured & passes -> green
run "" "true" ""
[ "$EC" -eq 0 ] && ok "test-only pass exit 0" || no "test-only exit ($EC)"

echo "verify-run tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
