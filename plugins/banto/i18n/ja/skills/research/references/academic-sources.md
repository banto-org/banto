# 学術ソース参照先（分野別）

> research / research-agent が学術トピックを調べるときの venue カタログ。
> エンジニア系（GitHub / Stack Overflow / 技術ブログ / 公式ドキュメント）とは分けて扱う — 混ぜると検索精度が落ちるため。
> 親 skill が分野を判定し、該当クラスタの venue を research-agent の起動プロンプトに渡す。

## 分野クラスタ

### AI / 機械学習 / 計算機科学

| venue | site: フィルタ | 役割 |
|---|---|---|
| arXiv | `site:arxiv.org` | プレプリントの第一選択 |
| alphaXiv | `site:alphaxiv.org` | arXiv 論文の議論・トレンド。コミュニティの注目度を見る |
| OpenReview | `site:openreview.net` | NeurIPS / ICLR / ICML の査読・採択 |
| Papers with Code | `site:paperswithcode.com` | 実装つき・SOTA 追跡 |
| Semantic Scholar | `site:semanticscholar.org` | 引用グラフ・横断検索 |

### 生命科学 / 医学 / 生物

| venue | site: フィルタ | 役割 |
|---|---|---|
| bioRxiv | `site:biorxiv.org` | 生物プレプリント |
| medRxiv | `site:medrxiv.org` | 医学プレプリント |
| PubMed | `site:pubmed.ncbi.nlm.nih.gov` | 査読済み医学・生命科学 |
| Nature | `site:nature.com` | 査読誌。最新号を優先 |
| Science | `site:science.org` | 査読誌 |

### 分野横断 / 一般

| venue | site: フィルタ | 役割 |
|---|---|---|
| Semantic Scholar / Google Scholar | `site:semanticscholar.org` / `site:scholar.google.com` | 分野をまたぐ横断検索・引用追跡 |
| 主要査読誌（PNAS / Cell / IEEE / ACM など） | 各誌ドメイン | 分野に応じて `{current_year}` つきで |

## 最新を取るルール

- プレプリント（arXiv / bioRxiv / medRxiv）は日付ソート＋ `{current_year}` で最新を取る。
- 査読誌（Nature / Science / PNAS）は「latest issue」「`{current_year}`」で最新号を取りに行く。
- alphaXiv / Papers with Code は trending / SOTA でコミュニティの注目を補足する。
- 論文ごとに タイトル・著者・日付・要約サマリー・（あれば）GitHub / Papers with Code リンク を必ず記録する。

## 使わない場面

- エンジニア / 実装系トピック → このカタログではなく GitHub / Stack Overflow / 公式ドキュメント。
- 混在トピック（例: ML ライブラリの実装）→ 両クラスタを併用するが、**論文は学術 venue・実装は GitHub** と明確に分けて扱う。
