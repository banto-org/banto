# 計画開示フロー（research）

事前承認は odd.yaml 宣言の 4 ゲート（ログイン必要媒体 / 8 並列以上 / **deep-research 起動** / 既存ファイル上書き）のみ。
計画自体は**テキスト提示して続行**する（事後開示。CONCEPT「approvals stay minimal」）。

## deep-research パスへルーティングした場合（高コストゲート）

サブトピックが高リスク・要反証で **deep-research**（高検証 Workflow）に振り分けられる場合は、ログイン必要媒体と同様に ❗ を付け、**起動前に必ず** user に確認する（odd.yaml ゲート。~4M トークン/~20分の高コスト）:

> 「{トピック} は反証検証が要る重大トピックなので deep-research（高検証・高コスト: 約4Mトークン/約20分）で調べます。よろしいですか？ 通常の research-agent 並列でよければそちらにします。」

- **Yes** → `Workflow({ name: "deep-research", args: "<精緻化した問い>" })` を**親（メインループ）から**起動 → 戻り値を output-format.md の deep-research テンプレで `{BASE}/docs/research/` に保存
- **No** → research-agent 並列パス（Step 3）に切り替え
- 環境に deep-research が無い → Workflow が解決失敗 → research-agent パスへ自動フォールバック（その旨を報告）

## Step 1: 調査項目の分解と計画提示（承認待ちしない）

Step 0 の結果を踏まえて、`$ARGUMENTS` を 3〜10 個のサブトピックに分解し、各サブトピックに**使用する媒体**を明記。Step 0 で既に判明した情報は「既存情報あり」と付記し、不足分のみ外部調査対象とする:

```
以下の内容を調査します（変更したい項目があれば伝えてください — このまま進めます）:

1. {サブトピック1} — 媒体: 公式ドキュメント（webread）
2. {サブトピック2} — 媒体: GitHub Issues（research-agent + WebSearch）
3. {サブトピック3} — 媒体: X（Claude in Chrome、ログイン必要）← ❗ 確認必要（odd.yaml ゲート）
4. {サブトピック4} — 媒体: arxiv（research-agent）
5. {サブトピック5} — 媒体: 技術ブログ（WebSearch）

※ Claude in Chrome を使う場合、Chrome 拡張がログイン済みである必要があります。
※ ログイン状態でないと該当項目は公開情報のみで代替します。
```

❗ 項目が 1 つも無ければそのまま Step 3 へ進む（Step 2 はスキップ）。

## Step 2: ログイン必要項目の user 確認

上記で ❗ が付いた項目について、**必ず** user に聞く:

> 「{サブトピックX} を調べるには {サービス名} にログイン状態でアクセスが必要です。Claude in Chrome で進めていいですか？」

- **Yes** → Claude in Chrome で調査
- **No** → 該当項目を WebSearch の公開情報のみに切り替え（結果品質が下がる旨を明記）
- **スキップ** → その項目を調査対象から外す

## Step 3: 並列調査実行

**起動前に親が 1 回だけ解決する（必須の契約）**: subagent は SessionStart 注入も `$CLAUDE_PLUGIN_ROOT` も持たないため、
親（research skill）が `BASE`（ai-context ベース。SessionStart 注入値 or `_ai-context-paths.sh --resolve`）と
`WEBREAD`（`$CLAUDE_PLUGIN_ROOT/scripts/webread.sh` の絶対パス）を解決し、**各 prompt に必ず埋め込む**。

**1 つのメッセージ内で複数の Agent tool 呼び出しを同時に送信**して並列実行:

```
// 必ず 1 つのメッセージで全て同時に呼び出すこと（逐次実行は禁止）
// 各 prompt に「保存先」と「webread パス」を必ず含める
Agent(subagent_type="research-agent", run_in_background=true,
  prompt="サブトピック1を公式ドキュメント中心に調査。保存先: {BASE}/docs/research/{YYYY-MM-DD}_{slug1}.md。webread: sh {WEBREAD} <URL>")
Agent(subagent_type="research-agent", run_in_background=true,
  prompt="サブトピック2を GitHub Issues で調査。保存先: {BASE}/docs/research/{YYYY-MM-DD}_{slug2}.md。webread: sh {WEBREAD} <URL>")
// 5〜10個を同時起動
```

**重要**: `run_in_background=true` を必ず指定し、全エージェントの完了通知を待ってから結果を統合する。

Claude in Chrome が必要な項目は**親セッションで直接実行**（サブエージェントは Chrome ツールを持たない）:

```
// ToolSearch で schema を先にロード
ToolSearch(query="select:mcp__claude-in-chrome__tabs_context_mcp,mcp__claude-in-chrome__navigate,mcp__claude-in-chrome__get_page_text")
// その後 Chrome ツールで調査
```
