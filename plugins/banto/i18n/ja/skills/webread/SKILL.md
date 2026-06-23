---
name: webread
description: |
  **UTILITY SKILL** — URL の本文全体を「LLM 要約を一切かけずに」クリーンな Markdown として取得し、本体モデルが直接読めるようにする。
  WebFetch の代替（WebFetch は小型モデルの要約を返すため、本文を実際に検証できない）。
  トリガー：URL とともに「読んで」「確認して」「中身見て」「要約して」が与えられたとき；ドキュメント／記事／ブログ／GitHub ページの精読。
  Do not use when：URL を*探す*とき（WebSearch / research skill）、ローカルファイル（直接 Read）、`.md` への直接リンク（WebFetch ではなく Read/curl を使う）。
  Depends on: python3 + trafilatura（純ローカル、LLM 不使用、本文抽出 F1=0.909）。scripts/webread.sh 経由。
allowed-tools: Bash Read Write
user-invocable: true
argument-hint: "[URL]"
compatibility: Claude Code (requires python3, trafilatura)
---

# WebRead — URL の本文全体を要約なしで取得する

## なぜ WebFetch ではなく WebRead か

`WebFetch` は取得したページを**小型モデルで要約して**返す。本体モデルが生の本文を一度も読まない
ため、欠落や歪みが生じる（要約は重要な詳細を黙って落とすことがある）。

WebRead は**trafilatura**（純ローカル、LLM 不使用）で本文全体を抽出し、**本体モデルがその全文を
直接 Read する**。要約が必要なときは、本体モデルが全文を読んだ後に要約する（小型モデルには決して
委ねない）。

## 手順

### 1. 取得（静的サイト = ニュース、ブログ、ドキュメント、GitHub）

```sh
sh "$CLAUDE_PLUGIN_ROOT/scripts/webread.sh" "<URL>" > /tmp/webread-out.md
```

**出力は必ず全文を Read する**（メタデータ付きの完全な Markdown 本文）。stdout が短ければ、インラインで読んでも構わない。

### 2. SPA / JS レンダリングのサイト（trafilatura が本文を抽出できない場合）

trafilatura は静的 HTML を取得するため、JS レンダリングの SPA では本文が空になることがある。
その場合に限り、**2 ステップ方式**を使う：

1. Claude in Chrome（`mcp__claude-in-chrome__navigate` → `get_page_text`）または Playwright MCP
   （`mcp__playwright__browser_navigate` → `document.documentElement.outerHTML` を渡した `browser_evaluate`）
   でレンダリング後の HTML を取得し、ファイルに保存する。
2. `sh "$CLAUDE_PLUGIN_ROOT/scripts/webread.sh" --html <saved.html>` で本文を抽出する。

### 3. 要約／回答（必要なときだけ）

本体モデルは**全文を読んだ後に**要約／回答する。WebFetch のように外部の小型モデルへプロンプトを
渡すことは決してしない。「内容を実際に検証すること」がこのスキルの存在理由である。

## 依存のインストール（無い場合）

```sh
pip install --user trafilatura
```

trafilatura が無い場合、webread.sh は curl による生の HTML にフォールバックする（タグ込み。本体モデルは依然としてそれを読む）。

## やってはいけないこと

- WebFetch を使う（このスキルの存在理由を打ち消す）。URL の精読は WebRead に統一する。
- 取得した本文を Read せずに結論を述べる（要約モデルに委ねるのと同じ誤り）。
- URL を探すために使う（それは WebSearch / research skill）。
