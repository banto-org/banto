# よくある間違い

## 構造（公式 Warning から）

公式 Plugins ページ Warning 原文引用:
> 「`commands/`、`agents/`、`skills/`、`hooks/` を `.claude-plugin/` ディレクトリ内に配置しないでください。`plugin.json` のみが `.claude-plugin/` 内に入ります。」

1. **`.claude-plugin/skills/` に配置** → 読み込まれない。plugin root 直下に置く
2. **プラグイン内 `rules/`** → 公式仕様外。`templates/rules/` に置いて install スクリプトで配布する方式が banto の選択
3. **commands/ で新規作成**（公式推奨ではない）→ 新規プラグインは `skills/` 推奨。既存 commands は引き続き機能（同名 skill があれば skill が優先）。移行は `mkdir -p skills/{name}` → `mv commands/{name}.md skills/{name}/SKILL.md` → `/reload-plugins`
4. **トップレベル `themes` / `monitors`** → 警告（将来 deprecated）。`experimental.themes` / `experimental.monitors` を使う
5. **プラグインルートの `CLAUDE.md`** → プラグインからは**読み込まれない**（公式明示）。skills / agents / hooks 経由で context を提供

## SKILL.md frontmatter

公式仕様:

6. **description が 1,024 字超**（Open Standard 上限）→ 短縮、または when_to_use と分割（合算 1,536 字まで）
7. **description + when_to_use 合算が 1,536 字超** → 表示カット発生、Claude が自動発火判断できない
8. **一人称 description** → "I can help..." ❌、三人称で "Helps users..." ✓
9. **allowed-tools がカンマ区切り** → 公式仕様外。スペース区切り or YAML 配列
10. **`version` フィールド** → SKILL.md frontmatter には公式仕様にない（plugin.json のみ）

### 旧版で誤って書かれていたもの（訂正）

- ❌ 旧:「`when_to_use` は公式非サポート、Claude は無視」
  → ✓ **公式サポート**。description と合算で 1,536 字キャップ
- ❌ 旧:「`license` / `metadata` / `compatibility` を削除すべき」
  → ✓ **Open Standard コアフィールド**。30+ ツール対応のため残すべき
- ❌ 旧:「description 250 字制限」
  → ✓ **1,024 字（Open Standard）/ 1,536 字（合算）**

## Hooks

公式 plugins-reference Common issues より:

11. **`echo "$INPUT" | jq`**（PostToolUse）→ content 内の `$()` でシェル展開リスク。**一時ファイル必須**
12. **`exit 1` でブロック** → ブロックには **`exit 2`**。`exit 1` は非ブロッキングエラー
13. **hook スクリプトの絶対パス** → `${CLAUDE_PLUGIN_ROOT}` を使う
14. **matcher の小文字** → `bash` ❌、`Bash` ✓ — ツール名・イベント名すべて大文字小文字区別
15. **matcher 未対応イベントに matcher** → `UserPromptSubmit`、`Stop`、`PostToolBatch`、`TaskCreated`、`TaskCompleted`、`TeammateIdle`、`CwdChanged`、`WorktreeCreate/Remove` 等は matcher なし
16. **hook スクリプトに実行権限なし** → `chmod +x hooks/*.sh` 必須
17. **`bash -x` / `set -x` / `env` で secret 露出** → `.env` の値が trace に出てチャット履歴に残る。個別変数だけ明示マスクで `echo`

## .mcp.json

18. **絶対パスで command 指定** → プラグイン更新で動かなくなる。`${CLAUDE_PLUGIN_ROOT}/...` を使う
19. **永続データを `${CLAUDE_PLUGIN_ROOT}` に書く** → プラグイン更新で消える。永続化は `${CLAUDE_PLUGIN_DATA}` を使う
20. **`type: stdio`（デフォルト）以外を使うのに `command` 指定** → http/sse/ws では `url` を使う

## Plugin Agent

21. **`hooks` / `mcpServers` / `permissionMode` をプラグイン agent に書く** → セキュリティ上**完全に無視される**（公式 sub-agents Note）。これらが必要な場合は `~/.claude/agents/` または `.claude/agents/` に配布

## 配布

22. **version を上げずにプラグイン更新** → キャッシュで既存ユーザーに届かない（公式: 「明示的なバージョンを使用する場合は semantic versioning に従う」）
23. **`plugin.json` に不明キー** → 警告なく無視される
24. **`claude plugin validate` を実行しない** → 構文エラーやスキーマ違反を見逃す
25. **CHANGELOG.md なし** → 公式は「`CHANGELOG.md` で変更を文書化」推奨

## 設計上のアンチパターン

26. **複雑な workflow skill に HeavySkill 4-component を使わない** → 単純なリスト形式の手順では複雑な判断が劣化（出典: arxiv 2605.02396）
27. **副作用ワークフローを自動発火可能にする** → 真に不可逆・外向きな副作用（`push` / `deploy` / `send` 等）は `disable-model-invocation: true` を検討（公式 Skills ページ）。
    **ただし intent-first が優先する**（北極星「全機能は自然文で到達可能」）: DMI は**例外**であり既定ではない。非破壊化できる workflow（read-only 監査・上書きに `--refresh` 必須・人間ゲート内蔵・承認制）は、**DMI ではなく「狭い固有 NL トリガー + 安全境界」で公開する**のが原則。DMI を付ける/残す場合は「不可逆性 or 高頻度語彙との不可分な衝突」という明文理由が必須（理由なき DMI は H-1 型の発見不能欠陥を生む）。
28. **リファレンスコンテンツに `context: fork`** → 公式 Warning:
    > 「`context: fork` は明示的な指示を含むスキルにのみ意味があります。スキルにタスクなしで「これらの API 規約を使用する」などのガイドラインが含まれている場合、サブエージェントはガイドラインを受け取りますが、実行可能なプロンプトがなく、意味のある出力なしで返されます。」
