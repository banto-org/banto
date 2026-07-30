# PORTABILITY — 中核とアダプタの分割

banto は Claude Code の plugin として実装されているが、思想層（rules・thinking-core・skill 指示文）
と ai-context store はホストに依存しない。本書は「どこまでが中核でどこからがアダプタか」を確定し、
Claude Code 以外のエージェント CLI への移植を段階的に進めるための正本とする。

決定の根拠: `decisions/2026-07-10-070500_multi-model-verification-and-portability-design` /
`docs/research/2026-07-10_multi-model-verification-services_research`（ai-context store 側）。

## 1. 中核（ホスト非依存）

次の 5 つはどのホストでも変更せず持ち運べる。

- hook 判定ロジックの純粋部分：払い出された payload の中身から判定を導く条件分岐そのもの。I/O の形式
  （JSON スキーマ・イベント名）はホスト依存だが、判定の中身は依存しない。
- ai-context store：`~/ai-context-store/<project>/` の decisions / docs / tasks / sessions 構造と
  検索ロジック。ホストがファイルシステム操作を持てば動く。
- templates/rules の散文：quality / safety / evidence-first / spec-fidelity / pii-protection /
  writing-ja。Markdown の平文で、ホストの注入機構に依存しない。
- thinking-core skill：作業契約 7 節（`skills/thinking-core/`）。散文のまま、どのホストの
  system prompt / AGENTS.md にも差し込める（banto 内では sonnet / haiku・旧世代モデル向けの
  オンデマンド skill — 5 系の Fable / Opus には不使用を徹底）。
- ODD スキーマと skill 指示文本体：`odd.schema.yaml` の構造と SKILL.md の本文は agentskills.io 準拠に
  近く、ホスト非依存で読める。

## 2. アダプタが吸収する 4 差分

移植先ごとに次の 4 点だけを翻訳すればよく、中核には手を入れない。

- イベント発火：Claude Code の `hooks.json`（PreToolUse / PostToolUse / SessionStart 等 10 種）を、
  対象ホストのイベント名・実行タイミングへ写像する。
- コンテキスト注入：SessionStart hook の stdout 注入と `~/.claude/rules/` の path-scoped 読み込みを、
  対象ホストの `AGENTS.md` 相当（Codex CLI）や extensions マニフェスト（Gemini CLI）へ置き換える。
- ツール権限：`allowed-tools` の記法を対象ホストの権限記法（Codex CLI の hooks 権限 / opencode の
  plugin 権限関数）へ変換する。
- skill 起動：Claude Code の Skill ツール呼び出しを、対象ホストの skill 実行機構（Codex CLI は
  agentskills.io 準拠で SKILL.md をほぼそのまま読める）へ差し替える。

## 3. 移植先の優先順位

第一候補は OpenAI Codex CLI。hooks（10 イベント・JSON I/O）・skills（agentskills.io 準拠）・
plugin（`.codex-plugin/plugin.json` + marketplace.json）の 3 層構造が Claude Code に最も近く、
移植コストが最小。第二候補は Gemini 系で、個人向け Gemini CLI は 2026 年 6 月 18 日に終了し
Antigravity CLI へ統合されたため、hooks 層（SessionStart・BeforeTool・AfterTool 等）のみ部分移植の
対象に留める。第三候補は opencode で、25 以上のイベントを持つ最細粒度 hooks は魅力的だが
TypeScript のプラグイン関数というコード駆動設計のため、POSIX sh 宣言的 hook からの変換コストが
Codex CLI 比で高い。

## 4. Claude Code 固有の結合点

| 結合点 | 内容 | アダプタでの吸収方法 |
|---|---|---|
| `hooks.json` 形式 | イベント名・matcher・command の JSON 配列 | 対象ホストのイベント名表と 1 対 1 の変換テーブルを持つ |
| payload JSON | stdin から渡される `tool_input` / `session_id` 等のフィールド | フィールド名の写像表を用意し、欠落フィールドは no-op で fail-open |
| `${CLAUDE_PLUGIN_ROOT}` | plugin 配布時のルートパス変数 | 対象ホストの同等変数（Codex CLI はプラグインルート相対パス）へ置換 |
| `settings.json` | ユーザー / プロジェクトスコープの権限・hook 登録 | 対象ホストの設定ファイル形式へ生成し直す（手編集は正本側で行う） |
| statusLine | セッション状態のステータスバー表示機構 | 対象ホストに同等機構がなければ縮退（省略可・必須ではない） |
| transcript 依存 | Stop hook 等の会話ログ参照ロジック | 対象ホストが会話ログを渡さない場合は該当チェックを無効化し、決定論チェック側で代替する |

## 5. Wave 2 実装計画（Codex CLI 向け）

1. `hooks.json` の 10 イベントを Codex CLI の 10 イベントへ写像するアダプタ表を作成する。
2. payload フィールド名の変換関数（`tool_input` ⇔ Codex CLI 相当フィールド）を実装する。
3. `${CLAUDE_PLUGIN_ROOT}` 依存箇所を洗い出し、Codex CLI のプラグインルート変数へ置換する。
4. 決定論 hook（kill-switch / egress-guard / verify-claim-guard）を優先移植し、散文層
   （export-agents-md.sh 成果物）と合流させる。
5. Codex CLI 環境での統合テスト（synthetic payload 単体テスト）を用意し、CI に追加する。
