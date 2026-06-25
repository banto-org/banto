# Paper / publishing / cross-technique exploration reference

Source: `{base}/docs/research/2026-06-24_paper-publishing-hf-github-arxiv.md`. The output is 3 publications: paper (arxiv) + HF + GitHub. **Every publish is a human gate**.

## Paper (arxiv / LaTeX)
- Template: the official ICLR / NeurIPS / ICML styles (owner picks per project). Overleaf × GitHub sync.
- Figures and tables are split into `plot.py` + reproduced in one shot via `make figures` (generated from execution output · no hand-typing).
- Reproducibility appendix: NeurIPS requires a Checklist at the end, ICLR a Reproducibility Statement. The ACM badge (Results Reproduced) is the industry standard.

## Hugging Face Hub
The model card must state `library_name` explicitly. Evaluation results are auto-aggregated to the Hub leaderboard via `.eval_results/*.yaml`. Publish a demo on Spaces (Gradio). Publishing weights requires a license check (human gate).

## GitHub + Zenodo
Satisfy the Papers with Code releasing-research-code checklist (README / environment / seed / config). Release → automatic Zenodo DOI. Register the link on Papers with Code.

## Cross-technique exploration (used in Survey)
- **Connected Papers** (visual cluster exploration) → **Semantic Scholar API** (cross-field keyword search) → **Papers with Code "Methods"** (tracking per-method usage history).
- Two stages: enumerate reuse candidates with an LLM → confirm they exist via the API. Reuse from seemingly unrelated papers is picked up here too.

## Claim ⇄ experiment ⇄ result
Tie them one-to-one in the claim ledger (run_id + config + seed + CI + baseline); claim-link.sh detects unbacked claims in paper.tex (the artifact-evaluation mindset).

> To be detailed in Phase 5 (T5.6).
