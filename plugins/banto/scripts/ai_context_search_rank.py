#!/usr/bin/env python3
"""ai_context_search_rank.py — deterministic implementation of ranking v3 (stdlib only)

search-native-migration spec T2-5. Design and 15-pattern validation:
  decisions/2026-06-07-224520_search-ranking-v3-and-similar-word-policy_*.md
  docs/[QA] search-eval-softmatcha-vs-native-2026-06-07.md (second round)

usage:
  python3 ai_context_search_rank.py --groups '<JSON>' --dirs <dir>... [--top 8] [--threshold 1.0]
  python3 ai_context_search_rank.py --groups '<JSON>' --base <ai-context base>
  python3 ai_context_search_rank.py --self-test

groups JSON format (weighted 3-tier expansion, assembled by the main model;
the JP terms below illustrate cross-language query expansion):
  [[1.0, ["監視", "モニタリング", "monitoring"]],
   [0.6, ["観測", "watch"]],
   [0.3, ["監査", "audit"]]]

Output: JSON {"confident": bool, "results": [{"score", "path", "hits"}...]}
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

# v3 rule 5: aggregate-style files subject to demotion
AGG_PAT = re.compile(r"\[Index\]|complete-guide|map-2026|-overview|\[QA\]")


def term_pattern(t: str) -> re.Pattern:
    """v3 rule 7: short ASCII terms (<4 chars) require word boundaries (guards PR→prompt mismatches)."""
    if re.fullmatch(r"[A-Za-z0-9_-]{1,3}", t):
        return re.compile(rf"\b{re.escape(t)}\b")
    return re.compile(re.escape(t), re.IGNORECASE)


def type_weight(rel: str) -> float:
    """v3 rule 4: document-type weight."""
    if rel.startswith("decisions/") or "/decisions/" in rel:
        return 1.0
    if "/research/" in rel or "/knowledges/" in rel:
        return 0.9
    if "/specs/" in rel:
        return 0.6
    return 0.7


def split_table_prose(text: str) -> tuple[str, str]:
    """v3 rule 6: separate tables (lines starting with |) and code-fence content (guards self-pollution by eval tables)."""
    tbl, prose, fence = [], [], False
    for line in text.split("\n"):
        s = line.strip()
        if s.startswith("```"):
            fence = not fence
            continue
        (tbl if (s.startswith("|") or fence) else prose).append(line)
    return "\n".join(prose), "\n".join(tbl)


def score_file(prose: str, tbl: str, rel: str, size_kb: float, groups) -> tuple[float, dict]:
    gscores, hit_groups, detail = [], 0, {}
    for w, terms in groups:
        c = 0.0
        for t in terms:
            pat = term_pattern(t)
            c += len(pat.findall(prose))
            c += 0.3 * len(pat.findall(tbl))  # rule 6: in-table/fence hits ×0.3
        if c > 0:
            hit_groups += 1
            detail[terms[0]] = round(c, 1)
        gscores.append(w * math.log1p(c))  # rules 1+3: tier weight × log saturation
    base = sum(gscores)
    if base == 0:
        return 0.0, {}
    diversity = 1 + 0.5 * (hit_groups - 1)  # rule 3: multi-group match bonus (soft-AND)
    agg = 0.3 if AGG_PAT.search(rel) else 1.0  # rule 5
    html = 0.5 if rel.endswith(".html") else 1.0  # rule 5
    size_pen = 1 / (1 + 0.3 * math.log10(size_kb + 1))  # rule 8
    # rule 9: bonus when a Tier1 term appears in the file name or first 200 chars
    head = prose[:200].lower()
    fname_bonus = 1.0
    if groups:
        for t in groups[0][1]:
            if t.lower() in rel.lower() or t.lower() in head:
                fname_bonus = 1.5
                break
    return base * diversity * type_weight(rel) * agg * html * size_pen * fname_bonus, detail


def rank(dirs: list[Path], groups, top: int, threshold: float) -> dict:
    results = []
    roots = [d.resolve() for d in dirs if d.exists()]
    for root in roots:
        for p in root.rglob("*"):
            if not (p.is_file() and p.suffix.lower() in (".md", ".html")):
                continue
            try:
                text = p.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            prose, tbl = split_table_prose(text)
            # rel is relative to root's parent, not the basename (keeps the decisions/ prefix)
            rel = str(p.relative_to(root.parent))
            s, detail = score_file(prose, tbl, rel, p.stat().st_size / 1024, groups)
            if s > 0:
                results.append({"score": round(s, 2), "path": str(p), "hits": detail})
    results.sort(key=lambda r: r["score"], reverse=True)
    confident = bool(results) and results[0]["score"] >= threshold  # rule 10: confidence threshold
    return {"confident": confident, "results": results[:top]}


# ---------------------------------------------------------------- self-test

def self_test() -> int:
    """Verify the v3 rules on synthetic fixtures (the 15 measured [QA] round-2 patterns condensed per rule).

    i18n: the JP strings in the fixtures and query groups below are test data exercising
    Japanese-text search behavior — do not translate them.
    """
    import tempfile
    failures = []

    def check(name, cond):
        print(("PASS" if cond else "FAIL") + f": {name}")
        if not cond:
            failures.append(name)

    with tempfile.TemporaryDirectory() as td:
        base = Path(td)
        dec = base / "decisions"
        docs = base / "docs"
        dec.mkdir()
        docs.mkdir()

        # fixture
        (dec / "auth-design.md").write_text("# 認証設計\n認証 認証 認可 OAuth で決定。\n", encoding="utf-8")
        (dec / "eval-tables.md").write_text(
            "# 評価\n比較した。\n| 認証 | 認証 | 認証 | 認証 | 認証 |\n| 認可 | 認可 | 認可 | 認可 | 認可 |\n",
            encoding="utf-8")
        (docs / "[Index] big-guide.md").write_text("認証 " * 50, encoding="utf-8")
        (dec / "pr-policy.md").write_text("# PR 運用\nPR は review 必須。PR PR\n", encoding="utf-8")
        (dec / "prompt-notes.md").write_text("# prompt 設計\nprompt prefix prompt prefix prompt prefix\n", encoding="utf-8")
        (dec / "symlink-supersede.md").write_text("# symlink 廃止\nsymlink を廃止し ポインタ に移行。\n", encoding="utf-8")
        (dec / "symlink-design.md").write_text("# symlink 設計\nsymlink symlink symlink symlink を採用。\n", encoding="utf-8")

        AUTH = [[1.0, ["認証", "auth"]], [0.6, ["認可"]], [0.3, ["ログイン"]]]

        # rule 6: in-table hit discount — table-heavy eval-tables cannot beat prose-written auth-design
        r = rank([dec, docs], AUTH, 8, 1.0)
        paths = [Path(x["path"]).name for x in r["results"]]
        check("rule6 in-table discount: auth-design ranks above eval-tables",
              paths.index("auth-design.md") < paths.index("eval-tables.md"))

        # rule 5: aggregate demotion — [Index] never reaches top1 even with 50 repeats of the Tier1 term
        check("rule5 aggregate demotion: [Index] is not top1", paths[0] != "[Index] big-guide.md")

        # rule 7: short-term boundary — a PR query must not hit prompt-notes (full of prompt/prefix)
        PRQ = [[1.0, ["PR"]], [1.0, ["review", "レビュー"]], [0.3, ["merge"]]]
        r = rank([dec, docs], PRQ, 8, 1.0)
        names = [Path(x["path"]).name for x in r["results"]]
        check("rule7 \\b boundary: prompt-notes does not hit on the PR query", "prompt-notes.md" not in names)
        check("rule7 correct: pr-policy is top1", names and names[0] == "pr-policy.md")

        # rules 2+3: independent intent-term group + diversity — on "symlink 廃止" supersede beats design
        SYM = [[1.0, ["symlink"]], [1.0, ["廃止", "supersede"]], [0.6, ["ポインタ"]]]
        r = rank([dec, docs], SYM, 8, 1.0)
        names = [Path(x["path"]).name for x in r["results"]]
        check("rule2/3 intent term + diversity: supersede is top1", names and names[0] == "symlink-supersede.md")

        # rule 10: confidence threshold — a nonexistent concept is not confident
        NEG = [[1.0, ["GraphQL"]], [0.6, ["Apollo"]], [0.3, []]]
        r = rank([dec, docs], NEG, 8, 1.0)
        check("rule10 threshold: negative query gives confident=False", r["confident"] is False)

        # rule 1: an adjacent-concept Tier3 must not dominate — a doc with only Tier2 terms < the Tier1 hit
        (dec / "approval-flood.md").write_text("認可 " * 30, encoding="utf-8")
        r = rank([dec, docs], AUTH, 8, 1.0)
        names = [Path(x["path"]).name for x in r["results"]]
        check("rule1 tier weights: Tier2 volume does not beat the Tier1 hit",
              names.index("auth-design.md") < names.index("approval-flood.md"))

    print(f"\n{'ALL PASS' if not failures else f'{len(failures)} FAILURES: ' + ', '.join(failures)}")
    return 0 if not failures else 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--groups", default="")
    ap.add_argument("--dirs", nargs="*", default=[])
    ap.add_argument("--base", default="")
    ap.add_argument("--top", type=int, default=8)
    ap.add_argument("--threshold", type=float, default=1.0)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    if not args.groups:
        print("--groups is required (except with --self-test)", file=sys.stderr)
        return 2
    groups = json.loads(args.groups)
    dirs = [Path(d) for d in args.dirs]
    if args.base:
        dirs += [Path(args.base) / "decisions", Path(args.base) / "docs"]
    if not dirs:
        print("--dirs or --base is required", file=sys.stderr)
        return 2
    print(json.dumps(rank(dirs, groups, args.top, args.threshold), ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
