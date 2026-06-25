# 論文 / 公開 / 技術横断探索リファレンス

出典: `{base}/docs/research/2026-06-24_paper-publishing-hf-github-arxiv.md`。出力は論文(arxiv) + HF + GitHub の 3 公開。**全公開は人間ゲート**。

## 論文（arxiv / LaTeX）
- テンプレ: ICLR / NeurIPS / ICML の公式スタイル（案件ごとに owner 指定）。Overleaf × GitHub 同期。
- 図表は `plot.py` 分離 + `make figures` 一発再現（実行出力から生成・手打ち禁止）。
- 再現性付録: NeurIPS は末尾 Checklist 必須、ICLR は Reproducibility Statement。ACM バッジ（Results Reproduced）が業界標準。

## Hugging Face Hub
モデルカードは `library_name` 明示必須。評価結果は `.eval_results/*.yaml` で Hub リーダーボードに自動集計。Spaces（Gradio）でデモ公開。重み公開はライセンス確認（人間ゲート）。

## GitHub + Zenodo
Papers with Code の releasing-research-code チェックリストを満たす（README / 環境 / seed / 設定）。Release → Zenodo 自動 DOI。Papers with Code へリンク登録。

## 技術横断探索（Survey で使う）
- **Connected Papers**（視覚的クラスタ探索）→ **Semantic Scholar API**（分野横断キーワード検索）→ **Papers with Code「Methods」**（手法別の使用実績追跡）。
- LLM で転用候補を列挙 → API で実在確認の 2 段。一見無関係な論文からの転用もここで拾う。

## 主張 ⇄ 実験 ⇄ 結果
claim 台帳（run_id + config + seed + CI + baseline）で一対一に紐づけ、claim-link.sh が paper.tex の unbacked 主張を検出する（artifact evaluation の考え方）。

> Phase 5（T5.6）で詳細化する。
