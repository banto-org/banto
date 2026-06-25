#!/bin/sh
# eval-stats.sh — model-lab Stage 6 statistics aggregator.
# Reads a multi-seed result set and emits mean±std + a 95% CI (BCa bootstrap when scipy
# is present, seeded percentile bootstrap otherwise) + an optional permutation test vs a
# baseline, then decides green/red and records an eval-last state for model-claim-guard.
#
# Usage: eval-stats.sh <results.jsonl> [baseline.jsonl]
#   each line: {"value": <number>}  (one per seed; other keys ignored)
# Verdict:
#   - BANTO_EVAL_TARGET set → green when the lower 95% CI bound >= target
#   - else baseline given   → green when permutation p < BANTO_EVAL_ALPHA (default 0.05) and mean improves
#   - else                  → report-only (green)
# Exit: 0 = green, 2 = red, 0 = fail-open (insufficient data / no python3).
set -u

RES=${1:-}
[ -n "$RES" ] || { echo "usage: eval-stats.sh <results.jsonl> [baseline.jsonl]" >&2; exit 0; }
[ -f "$RES" ] || { echo "eval-stats: $RES not found (fail-open)"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "eval-stats: python3 absent — skipped (fail-open)"; exit 0; }

OUT=$(python3 - "$RES" "${2:-}" <<'PY'
import sys, os, json, random
random.seed(0)

def load(path):
    vals = []
    if not path:
        return vals
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    o = json.loads(line)
                except Exception:
                    continue
                v = o.get('value', o.get('metric_value'))
                if isinstance(v, (int, float)):
                    vals.append(float(v))
    except Exception:
        pass
    return vals

res = load(sys.argv[1])
base = load(sys.argv[2]) if len(sys.argv) > 2 else []
if len(res) < 2:
    print("eval-stats: need >=2 result values; got %d (fail-open)" % len(res))
    sys.exit(3)

n = len(res); mean = sum(res) / n
std = (sum((x - mean) ** 2 for x in res) / (n - 1)) ** 0.5

ci_method = 'percentile'
try:
    import numpy as np
    from scipy import stats as st
    b = st.bootstrap((np.array(res),), np.mean, confidence_level=0.95,
                     method='BCa', n_resamples=2000, random_state=0)
    lo, hi = float(b.confidence_interval.low), float(b.confidence_interval.high)
    ci_method = 'BCa'
except Exception:
    B = 2000; ms = []
    for _ in range(B):
        s = [random.choice(res) for _ in range(n)]
        ms.append(sum(s) / n)
    ms.sort(); lo = ms[int(0.025 * B)]; hi = ms[int(0.975 * B)]

pval = None
if len(base) >= 2:
    try:
        import numpy as np
        from scipy import stats as st
        def md(a, b): return a.mean() - b.mean()
        pr = st.permutation_test((np.array(res), np.array(base)), md,
                                 n_resamples=2000, random_state=0, alternative='greater')
        pval = float(pr.pvalue)
    except Exception:
        obs = mean - (sum(base) / len(base)); pool = res + base; cnt = 0; B = 2000
        for _ in range(B):
            random.shuffle(pool)
            a = pool[:n]; bb = pool[n:]
            if (sum(a) / n - sum(bb) / len(bb)) >= obs:
                cnt += 1
        pval = cnt / B

target = os.environ.get('BANTO_EVAL_TARGET')
alpha = float(os.environ.get('BANTO_EVAL_ALPHA', '0.05'))
verdict = 'green'; reason = 'report-only'
if target:
    t = float(target)
    verdict, reason = ('green', '') if lo >= t else ('red', 'lowerCI %.4g < target %.4g' % (lo, t))
elif pval is not None:
    improved = mean > (sum(base) / len(base))
    verdict, reason = ('green', '') if (pval < alpha and improved) else ('red', 'p=%.4g not<%.4g or no gain' % (pval, alpha))

print('eval-stats: n=%d mean=%.4g std=%.4g ci95[%s]=[%.4g,%.4g]%s verdict=%s %s' % (
    n, mean, std, ci_method, lo, hi,
    (' p=%.4g' % pval) if pval is not None else '', verdict, reason))
sys.exit(0 if verdict == 'green' else 2)
PY
)
RC=$?
echo "$OUT"

STATE_DIR="${ODD_STATE_DIR:-$HOME/.cache/banto}"
mkdir -p "$STATE_DIR" 2>/dev/null || true
case "$RC" in
    0) printf 'green\n' > "$STATE_DIR/eval-last-cli" 2>/dev/null || true ;;
    2) printf 'red:eval\n' > "$STATE_DIR/eval-last-cli" 2>/dev/null || true ;;
    *) exit 0 ;;  # fail-open: do not record a verdict
esac
exit "$RC"
