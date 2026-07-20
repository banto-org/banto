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

Output: JSON {"confident": bool, "results": [{"score", "path", "hits", "date", "age_days", "derived"}...]}

v3.1 (decision 2026-07-17 freshness-newest-first): score is only the relevance gate
(confidence + top-N selection); the presented order is newest-first by filename date.
Primary docs come before derived records ([Index]/[Status]/[QA]/aggregates), dateless
files sort last, score breaks ties. age_days makes staleness visible before any Read.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import re
import sys
from pathlib import Path


def base_dirs(base: Path, project_root: Path) -> list[Path]:
    """{base}/decisions + {base}/docs + existing extra_docs_dirs from {base}/config.json.

    Mirrors ai_context_combined.py: extra_docs_dirs are project-root-relative path strings
    under the top-level "extra_docs_dirs" key; missing dirs are skipped.
    """
    dirs = [base / "decisions", base / "docs"]
    config_path = base / "config.json"
    if config_path.exists():
        try:
            config = json.loads(config_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            config = {}
        for d in config.get("extra_docs_dirs", []):
            p = (project_root / d).resolve()
            if p.exists() and p.is_dir():
                dirs.append(p)
    return dirs

# v3 rule 5 + v3.1: aggregate/derived records subject to score demotion and
# presentation demotion (derived records are always the newest files, so a
# newest-first order without this demotion would surface them above decisions)
AGG_PAT = re.compile(r"\[Index\]|\[Status\]|complete-guide|map-2026|-overview|\[QA\]")

# v3.2: front-matter status demotion — a doc that says it is outdated must not outrank
# the living one, whatever its term match. Only the YAML head is consulted (cheap).
STATUS_PAT = re.compile(r"^status:\s*([\w-]+)", re.MULTILINE)
STALE_STATUSES = {"superseded", "stale", "deprecated", "rejected"}


def head_status(text: str) -> str:
    """front-matter status from the first 400 bytes; '' when absent."""
    if not text.startswith("---"):
        return ""
    m = STATUS_PAT.search(text[:400])
    return m.group(1).lower() if m else ""


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
            st = head_status(text)
            if st in STALE_STATUSES:
                s *= 0.3  # v3.2: self-declared outdated docs lose to living ones
            if s > 0:
                results.append({"score": round(s, 2), "path": str(p), "hits": detail, "status": st})
    results.sort(key=lambda r: r["score"], reverse=True)
    confident = bool(results) and results[0]["score"] >= threshold  # rule 10: confidence threshold
    return {"confident": confident, "results": present(results[:top])}


def present(rows: list[dict], today: dt.date | None = None) -> list[dict]:
    """v3.1 newest-first presentation: relevance selected the rows; the date orders them.

    Sort contract: primary docs before derived records, then filename date desc
    (dateless last), then score desc. Stable three-pass sort, least significant first.
    """
    today = today or dt.date.today()
    for r in rows:
        d = _extract_date(r["path"])
        r["date"] = d
        try:
            r["age_days"] = (today - dt.date.fromisoformat(d)).days if d else None
        except ValueError:
            r["age_days"] = None
        r["derived"] = bool(AGG_PAT.search(Path(r["path"]).name))
    rows.sort(key=lambda r: r["score"], reverse=True)
    rows.sort(key=lambda r: r["date"], reverse=True)  # ISO strings; "" (dateless) sorts last
    # derived records and self-declared stale docs both go last (v3.1 + v3.2)
    rows.sort(key=lambda r: r["derived"] or r.get("status", "") in STALE_STATUSES)
    return rows


# ------------------------------------------------------- 3-layer retrieval

# leading YYYY-MM-DD (optionally -HHMMSS) in a decision/research filename
DATE_PAT = re.compile(r"(\d{4}-\d{2}-\d{2})(?:-\d{6})?")


def _extract_date(path: str) -> str:
    """Pull the leading date out of a store filename (decisions/research convention); '' if none."""
    m = DATE_PAT.search(Path(path).name)
    return m.group(1) if m else ""


def layered(ranked: dict, index_top: int) -> dict:
    """Wrap rank() output into claude-mem's 3-layer retrieval shape (token-budget control).

    The model reads layers progressively and only Read-opens full files when needed:
      - layer1 index   : compact one-liner per hit (path + score + matched terms) — cheapest
      - layer2 timeline: the same hits ordered by date (chronological context)
      - layer3 full    : the existing detailed rows ({score, path, hits}) — last, before Read

    Additive only: the underlying confident/results are preserved verbatim under layer3.
    """
    results = ranked["results"]
    index = [
        {"path": r["path"], "score": r["score"], "date": r.get("date", ""),
         "age_days": r.get("age_days"), "terms": list(r["hits"].keys())}
        for r in results[:index_top]
    ]
    timeline = sorted(
        ({"date": _extract_date(r["path"]), "path": r["path"], "score": r["score"]} for r in results),
        key=lambda e: e["date"],
        reverse=True,
    )
    return {
        "confident": ranked["confident"],
        "layers": {"index": index, "timeline": timeline, "full": results},
    }


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

        # 3-layer retrieval (claude-mem index→timeline→full): additive wrapper over rank()
        (dec / "2026-01-10_auth-old.md").write_text("# 旧 認証\n認証 認証 認証 を採用。\n", encoding="utf-8")
        (dec / "2026-06-20-091500_auth-new.md").write_text("# 新 認証\n認証 認証 認証 認証 へ移行。\n", encoding="utf-8")
        raw = rank([dec, docs], AUTH, 8, 1.0)
        lay = layered(raw, index_top=3)
        check("3layer: layers has index/timeline/full",
              set(lay["layers"].keys()) == {"index", "timeline", "full"})
        check("3layer: full layer equals raw results (additive, no scoring change)",
              lay["layers"]["full"] == raw["results"])
        check("3layer: confident is carried through unchanged",
              lay["confident"] == raw["confident"])
        check("3layer: index is compact and capped by index_top",
              len(lay["layers"]["index"]) <= 3
              and all(set(e.keys()) == {"path", "score", "date", "age_days", "terms"}
                      for e in lay["layers"]["index"]))
        tl_dates = [e["date"] for e in lay["layers"]["timeline"] if e["date"]]
        check("3layer: timeline is newest-first by filename date",
              tl_dates == sorted(tl_dates, reverse=True)
              and "2026-06-20" in tl_dates and "2026-01-10" in tl_dates
              and tl_dates.index("2026-06-20") < tl_dates.index("2026-01-10"))

        # v3.1 newest-first presentation (decision 2026-07-17 freshness-newest-first)
        names = [Path(x["path"]).name for x in raw["results"]]
        check("v3.1 newest-first: dated hits are presented newest-first",
              names.index("2026-06-20-091500_auth-new.md") < names.index("2026-01-10_auth-old.md"))
        check("v3.1 newest-first: dateless hits come after dated ones",
              names.index("2026-01-10_auth-old.md") < names.index("auth-design.md"))
        check("v3.1 newest-first: dateless ties keep relevance order",
              names.index("auth-design.md") < names.index("approval-flood.md"))
        top_row = raw["results"][0]
        check("v3.1 age_days: dated rows carry a non-negative age",
              isinstance(top_row["age_days"], int) and top_row["age_days"] >= 0
              and top_row["date"] == "2026-06-20")
        check("v3.1 confidence: still computed from the relevance top score",
              raw["confident"] is True)
        # derived records ([Status] etc.) stay last even when they are the newest
        (docs / "[Status] auth-weekly-2026-06-25.md").write_text("認証 認証 認証 の週次報告。\n", encoding="utf-8")
        r = rank([dec, docs], AUTH, 10, 1.0)
        names = [Path(x["path"]).name for x in r["results"]]
        check("v3.1 derived demotion: newest [Status] still sorts after primary docs",
              names.index("2026-01-10_auth-old.md") < names.index("[Status] auth-weekly-2026-06-25.md")
              and r["results"][names.index("[Status] auth-weekly-2026-06-25.md")]["derived"] is True)

        # v3.2: front-matter status demotion — a superseded doc never outranks the living one
        (dec / "2026-07-01-120000_auth-superseded.md").write_text(
            "---\nstatus: superseded\ndate: 2026-07-01\n---\n# 旧 認証方針\n認証 認証 認証 認証 認証 認証 で決定。\n",
            encoding="utf-8")
        r = rank([dec, docs], AUTH, 10, 1.0)
        names = [Path(x["path"]).name for x in r["results"]]
        sup = r["results"][names.index("2026-07-01-120000_auth-superseded.md")]
        check("v3.2 status demotion: superseded doc sorts after living dated docs",
              names.index("2026-06-20-091500_auth-new.md") < names.index("2026-07-01-120000_auth-superseded.md")
              and names.index("2026-01-10_auth-old.md") < names.index("2026-07-01-120000_auth-superseded.md"))
        check("v3.2 status carried in output rows", sup["status"] == "superseded")

    print(f"\n{'ALL PASS' if not failures else f'{len(failures)} FAILURES: ' + ', '.join(failures)}")
    return 0 if not failures else 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--groups", default="")
    ap.add_argument("--dirs", nargs="*", default=[])
    ap.add_argument("--base", default="")
    ap.add_argument("--project-root", default="")
    ap.add_argument("--top", type=int, default=8)
    ap.add_argument("--threshold", type=float, default=1.0)
    ap.add_argument("--layered", action="store_true",
                    help="emit claude-mem 3-layer retrieval (index/timeline/full) for token-budget control")
    ap.add_argument("--index-top", type=int, default=5)
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
        project_root = Path(args.project_root).resolve() if args.project_root else Path.cwd()
        dirs += base_dirs(Path(args.base), project_root)
    if not dirs:
        print("--dirs or --base is required", file=sys.stderr)
        return 2
    ranked = rank(dirs, groups, args.top, args.threshold)
    out = layered(ranked, args.index_top) if args.layered else ranked
    print(json.dumps(out, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
