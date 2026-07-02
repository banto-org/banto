# research 出力フォーマット

> テンプレ見出しは構造の雛形。対象ドキュメントは会話言語で記述する（英語見出しは対象言語に翻訳してよい）。

結果を ai-context ベース配下の `{base}/docs/research/{YYYY-MM-DD}_{topic-slug}.md` に保存する（`{base}` は agent 本文の手順で解決した絶対パス。相対 `.ai-context/` には書かない）。

## 必須: `## Sources` に URL を必ず残す（検証導線）

保存するリサーチには**例外なく** `## Sources` セクションを設け、参照した一次ソースの URL を列挙する（出典の無い情報には価値がない）。各 Sources の冒頭に、人間/エージェントが本文を再検証できるよう一行の affordance を添える:

```markdown
## Sources

> 検証: `/webread <url>`（trafilatura 全文取得・LLM 要約なし）で各ソースの本文を再確認できる。

- [Source 1](URL)
- [Source 2](URL)
```

## テンプレート

```markdown
# {トピック} 調査結果

- **調査日**: YYYY-MM-DD
- **調査者**: AI (Claude)
- **使用媒体**: {公式ドキュメント / GitHub / arxiv / X (Chrome) / WebSearch}

## TL;DR
{3〜5 行の要約}

## 詳細

### {サブトピック1}
{内容}
- 出典: [タイトル](URL)

### {サブトピック2}
...

## Claude in Chrome で得た情報（該当する場合）
{ログイン必須だったサイトから得た情報、キャプチャ要約等}

## Sources
> 検証: `/webread <url>` で各ソースの本文を再確認できる。
- [Source 1](URL)
- [Source 2](URL)

## 信頼度
- **高**: 公式ドキュメント、主要プロジェクトの README/CHANGELOG
- **中**: 著名な技術ブログ、Stack Overflow 回答（承認済み）
- **低**: SNS の個人意見、古いブログ
```

## deep-research（高検証パス）の戻り値を保存するテンプレート

deep-research（Workflow）は**保存しない**ため、戻り値オブジェクト（`summary` / `findings[]` / `caveats` / `sources` / `refuted[]` / `stats`）を下記に整形して `{base}/docs/research/{YYYY-MM-DD}_{slug}.md` に保存する（これが banto 統合の本体 = 永続化）。

```markdown
# {トピック} 調査結果（deep-research 高検証）

- **調査日**: YYYY-MM-DD
- **使用媒体**: deep-research（5フェーズ・3票敵対的検証）
- **検証統計**: ソース {stats.sourcesFetched} / 抽出主張 {stats.claimsExtracted} / 確定 {stats.confirmed} / 棄却 {stats.killed}

## TL;DR
{summary をそのまま、または要約}

## 検証済みの発見（findings）
### {finding.claim}
- 確信度: {finding.confidence} ／ 投票: {finding.vote}
- 根拠: {finding.evidence}
- 出典: {finding.sources を箇条書き}

## 留意（caveats）
{caveats}

## 棄却された主張（透明性のため）
- {refuted[].claim}（投票 {refuted[].vote} / {refuted[].source}）

## Sources
> 検証: `/webread <url>` で各ソースの本文を再確認できる（特に deep-research は URL 幻覚の可能性があるため重要引用は webread で実体確認する）。
- {sources を URL + 品質で列挙}

## 信頼度
- deep-research の確信度（high/medium/low）をそのまま採用。URL は幻覚混入の可能性があるため重要引用はリンク健全性を確認
```

保存後、過去の `decisions/` / 既存 research との整合を確認・報告する（store-first 統合）。

## 主要な発見を報告

ドキュメント作成後、ユーザーに **3〜5 点** の主要な発見事項を報告する。保存先パスも必ず伝える。
