#!/bin/sh
# banto clean-room test — runs inside a fresh ubuntu container against the public export.
# Verifies the deterministic layers on GNU userland + dash (no Claude session required).
# Usage: sh scripts/export-public.sh /tmp/banto-public-export && \
set -u
export DEBIAN_FRONTEND=noninteractive
echo "== [0] toolchain =="
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq git jq python3 python3-yaml >/dev/null 2>&1
git --version && jq --version && python3 --version
sh --version 2>/dev/null || readlink -f /bin/sh

# Work on a writable copy (the mount is read-only)
cp -R /src /work && cd /work
git config --global user.email cleanroom@example.com
git config --global user.name cleanroom
git config --global init.defaultBranch main

fail=0
note() { printf '\n== [%s] %s ==\n' "$1" "$2"; }
res() { if [ "$1" -eq 0 ]; then echo "  -> PASS"; else echo "  -> FAIL"; fail=1; fi; }

note 1 "sh -n (dash) on all scripts"
f1=0; for f in $(find . -name '*.sh' -not -path './.git/*'); do sh -n "$f" || { echo "  SH FAIL: $f"; f1=1; }; done; res $f1

note 2 "jq validity on all json"
f2=0; for f in $(find . -name '*.json' -not -path './.git/*'); do jq empty "$f" 2>/dev/null || { echo "  JSON FAIL: $f"; f2=1; }; done; res $f2

note 3 "py_compile on all python"
f3=0; for f in $(find . -name '*.py' -not -path './.git/*'); do python3 -m py_compile "$f" || { echo "  PY FAIL: $f"; f3=1; }; done; res $f3

note 4 "yaml validity (odd templates)"
python3 -c "
import glob, yaml
for p in glob.glob('plugins/banto/templates/odd/*.yaml'):
    yaml.safe_load(open(p))
print('  yaml OK')"; res $?

note 5 "brand gates (legacy names)"
sh scripts/check-legacy-names.sh --code && sh scripts/check-legacy-names.sh; res $?

note 6 "unit tests (wiring + resolver + release-guard) on dash/GNU"
sh plugins/banto/scripts/test-ai-context-paths-wiring.sh; r1=$?
sh plugins/banto/scripts/test-resolve-store-path.sh; r2=$?
sh plugins/banto/scripts/test-release-guard.sh; r3=$?
[ $r1 -eq 0 ] && [ $r2 -eq 0 ] && [ $r3 -eq 0 ]; res $?

note 7 "plugin-audit pipeline (collect -> report -> matrix) on GNU awk/sed"
sh plugins/banto/scripts/plugin-audit-collect.sh plugins/banto > /tmp/c.tsv 2>/tmp/c.err; rc=$?
lines=$(wc -l < /tmp/c.tsv)
echo "  collect: exit=$rc rows=$lines (expect 60+; stderr: $(head -c 120 /tmp/c.err))"
sh plugins/banto/scripts/plugin-audit-report.sh < /tmp/c.tsv > /tmp/r.md 2>&1; rr=$?
echo "  report: exit=$rr lines=$(wc -l < /tmp/r.md)"
sh plugins/banto/scripts/plugin-audit-matrix.sh plugins/banto > /tmp/m.md 2>&1; rm_=$?
echo "  matrix: exit=$rm_ lines=$(wc -l < /tmp/m.md)"
grep -n "command not found\|syntax error\|No such file" /tmp/r.md /tmp/m.md && f7=1 || f7=0
[ $rc -eq 0 ] && [ $rr -eq 0 ] && [ $rm_ -eq 0 ] && [ "$lines" -gt 50 ] && [ $f7 -eq 0 ]; res $?

note 8 "hook synthetic payloads (dash)"
H=plugins/banto/hooks
# 8a decisions-numbering: expects naming injection when decisions/ exists
mkdir -p /tmp/proj/.ai-context/decisions
out=$(printf '{"cwd":"/tmp/proj","hook_event_name":"PreToolUse","tool_input":{"file_path":"/tmp/proj/.ai-context/decisions/new.md"}}' | sh $H/ai-context-decisions-numbering.sh)
case "$out" in *"[Decisions Naming]"*) echo "  8a naming injection: ok";; *) echo "  8a naming injection: FAIL"; fail=1;; esac
# 8b egress-guard: no registry -> must be a silent no-op exit 0
out=$(printf '{"cwd":"/tmp/proj","tool_input":{"file_path":"/tmp/proj/x.md","content":"hello"}}' | sh $H/egress-guard.sh); rc=$?
echo "  8b egress-guard no-registry: exit=$rc (expect 0)"; [ $rc -eq 0 ] || fail=1
# 8c odd-kill-switch: direct push to main from a code repo must block (exit 2)
cd /work && git add -A >/dev/null 2>&1 && git commit -qm init >/dev/null 2>&1
printf '{"cwd":"/work","tool_input":{"command":"git push origin main"}}' | sh $H/odd-kill-switch.sh >/dev/null 2>/tmp/ks.err; rc=$?
echo "  8c kill-switch push-to-main: exit=$rc (expect 2; stderr: $(head -c 100 /tmp/ks.err))"; [ $rc -eq 2 ] || fail=1
# 8d safety-guard: raw .env read must block (its actual contract: secret exfil, not rm)
printf '{"cwd":"/work","tool_input":{"command":"cat .env"}}' | sh $H/safety-guard.sh >/dev/null 2>/tmp/sg.err; rc=$?
echo "  8d safety-guard cat .env: exit=$rc (expect 2; stderr: $(head -c 100 /tmp/sg.err))"; [ $rc -eq 2 ] || fail=1
# 8e safety-guard: .env.example must NOT block (documented exception)
printf '{"cwd":"/work","tool_input":{"command":"cat .env.example"}}' | sh $H/safety-guard.sh >/dev/null 2>&1; rc=$?
echo "  8e safety-guard cat .env.example: exit=$rc (expect 0)"; [ $rc -eq 0 ] || fail=1

printf '\n========================\n'
if [ $fail -eq 0 ]; then echo "CLEAN-ROOM: ALL PASS"; else echo "CLEAN-ROOM: FAILURES PRESENT"; fi
exit $fail
