---
name: plugin-dev
description: |
  Claude Code プラグインまたは単一スキルの新規作成・改修を支援する。公式ベストプラクティスに基づき skill / plugin / hook を scaffold、または既存スキルを改修する（`refactor <skill-path>`）。INVOKES: 品質スコアリングのため plugin-audit skill と連動する。
  トリガー: 「プラグイン作って」「スキル作って」「フック作って」「skill 改修」
  使ってはいけない場面: 単純な 1 ファイル設定変更 — この skill はスキップし、直接 Edit で十分。
user-invocable: true
argument-hint: "[プラグインの説明 / refactor skills/<name>]"
model: opus
allowed-tools: Read Write Edit Glob Grep Bash(mkdir:*) Bash(chmod:*) Skill
compatibility: Claude Code (requires bash, git, jq)
---

# Plugin Dev — Claude Code プラグイン開発支援

詳細なリファレンス資料は `references/` にある。必要なときだけ読むこと。
ユーザーが日本語で会話している場合は日本語で応答する。

公式の根拠: https://code.claude.com/docs/en/plugins-reference （[`references/sources.md`](references/sources.md) も参照）。

## Standalone vs Plugin

| 基準 | Standalone (`.claude/`) | Plugin |
|---------|----------------------|---------|
| スキル名 | `/hello` | `/plugin-name:hello` |
| 向いている用途 | 個人ワークフロー、実験 | チーム共有、配布 |
| 共有 | 手動コピー | `claude plugin install` |

**迷ったら**: `.claude/` で実験 → プラグインに変換。

## モード判定（new / refactor）

`$ARGUMENTS` が `refactor skills/<name>` または既存スキルパスで始まる → **refactor モード**（下記）。それ以外 → 新規作成（Step 1 以降）。

### Refactor モード（スキル単独改修）

既存スキル 1 つの品質を引き上げる:

1. 対象 SKILL.md を Read + `plugin-audit-usage.sh --skill <path>` で利用状況を確認
2. `references/quality-scoring.md` の High 基準（`USE FOR / DO NOT USE FOR / INVOKES`、≤50 語のルーティング、progressive loading）と突き合わせる
3. 改善提案を提示（description 書き換え / references/ への分割 / allowed-tools の最小化 = Axis 12）
4. 提案をテキストで提示し Edit で適用（事後開示。ゴール分岐がある場合のみ停止、例: トリガー語 / 起動経路を変えてしまう変更）
5. 適用後、`plugin-audit skills/<name>`（スキル単独監査）で再検証

新規作成と違い、最優先は **既存のトリガー語と起動経路を壊さないこと**（後方互換）。

## Step 1: 要件ヒアリング

テキストで確認:
- プラグイン名（kebab-case、最大 64 文字）
- 何をするか
- 必要なコンポーネント（skill/hook/agent/MCP）
- 配布先（local / marketplace）

## Step 2: ディレクトリ構造

`.claude-plugin/` には **plugin.json のみ** を置く。それ以外はすべてプラグインルート直下に置く。

```
{name}/
├── .claude-plugin/plugin.json   ← only this lives here
├── skills/{skill}/SKILL.md
├── agents/{agent}.md
├── hooks/hooks.json + *.sh
├── templates/rules/{topic}.md   ← path-scoped rule (Layer 3 trio candidate)
├── .mcp.json
├── settings.json                ← agent default settings (optional)
└── README.md
```

## Step 2.2: Layer 3 trio 判定（skill + rule + hook）

新規スキルが以下のいずれかを含む場合、**rule + hook** を併設するか判断する。詳細: [`references/layer3-trio.md`](references/layer3-trio.md)

**trio 候補シグナル**:
- 特定ファイル種別（`*.ts` / `*.py` / `.env` / `package.json` など）と紐づく → **path-scoped rule** を追加
- 「必ず X」「絶対 Y しない」「禁止」を含む → **hook (PreToolUse)** による deterministic enforce を検討
- 静的な禁止として表現できる（main へ push しない / `.env` を `cat` しない）→ **permissions.deny** で十分（hook より軽い）

**trio が不要なケース**（軽量 utility / 概念的な行動原則 / 単一ファイル種別で完結する手順）の詳細は [`references/layer3-trio.md`](references/layer3-trio.md) の「不要な 3 点セットを避ける判断」を参照。

**迷ったら skill だけ作る → 運用で必要が出たら後から追加する**（過剰設計を避ける）。

## Step 2.5: 複雑度チェック → HeavySkill 適用判定（AI 自動）

新規スキルが以下のいずれかに該当する場合、**HeavySkill 4-component テンプレ** を提案する:

**自動判定基準**（いずれか 1 つ該当で対象）:
- description / 目的文に「複雑」「判断」「分析」「設計」「議論」「比較」「トレードオフ」「悩む」「迷う」「多視点」「合議」（EN: "complex", "decision", "analysis", "design", "deliberation", "comparison", "trade-off", "torn between", "multi-perspective", "consensus"）のような語を含む
- スキル分類が `**WORKFLOW SKILL**`
- 入力が「複数選択肢から最良を選ぶ」「相反する制約を満たす」「設計判断を下す」を含む
- ユーザーが複雑な分岐 / 多角的評価 / 並列推論を明示的に言及（「複雑な分岐がある」「多角的に評価したい」「並列で考えたい」）

**判定の優先順位**:
1. ユーザーの明示要求 > 自動キーワード一致 > スキル分類
2. 単純な utility / analysis skill（例: typo 修正、format 変換、status 表示）には HeavySkill を **適用しない**

**該当する場合**: テキストで確認:
- A: HeavySkill 4-component（重め、高品質、並列 + 審議）→ `references/heavyskill-template.md`
- B: 標準テンプレ（軽量）→ `references/skill-md.md`

**該当しない場合**: 標準テンプレで進める（採用解釈）。

詳細: `references/heavyskill-template.md`（HeavySkill 4-component の使い方と適用基準）

## Step 3: ファイル生成

コンポーネントごとの詳細テンプレは references/ を参照:

- plugin.json → [references/plugin-json.md](references/plugin-json.md)
- SKILL.md（標準）→ [references/skill-md.md](references/skill-md.md)
- SKILL.md（HeavySkill 4-component）→ [references/heavyskill-template.md](references/heavyskill-template.md)
- hooks.json + hook スクリプト（**頻出イベント + 全 29 一覧**）→ [references/hooks-json.md](references/hooks-json.md)
- .mcp.json → [references/mcp-json.md](references/mcp-json.md)
- agents/*.md（**plugin agent の制限が適用される**）→ [references/agents.md](references/agents.md)
- commands/ は skills/ にマージ済み。新規は必ず `skills/` に作る。
- **Layer 3 trio（skill + rule + hook）** → [references/layer3-trio.md](references/layer3-trio.md)
- 品質スコアリング基準 → [references/quality-scoring.md](references/quality-scoring.md)
- 設計パターン（呼出制御 / スキル種別 / ループ設計）→ [references/skill-design-patterns.md](references/skill-design-patterns.md)
- よくある間違い → [references/common-mistakes.md](references/common-mistakes.md)

### ドキュメント生成スキルを作るとき（特殊ケース）

プラグインに **ドキュメントを保存するスキル**（`[Review] [QA] [Audit] [Status] [Design] [Guide] [Memo] [Index]` など）を追加するときは、単独実装せず共通パターンに従う:

1. `${CLAUDE_PLUGIN_ROOT}/templates/docs/_common-pattern.md` を Read
2. Pattern A（agent 起動型）か B（穴埋めテンプレ型）かを判断
3. SKILL.md の冒頭に明記: 「**Pattern A/B** — 共通スケルトンは `_common-pattern.md` 参照」
4. スキル固有情報のみ記述（起動する agent / 保存プレフィックス / モード分岐 / スキル固有テンプレ）
5. 新しいプレフィックスが必要なら `ai-context/SKILL.md` のリストに追加（hook で強制されるリストに反映）
6. `kit` / `README.md` のドキュメント生成セクションに 1 行追加

## Steps 4-6: テスト / 配布 / 監査

```bash
# Local test
claude --plugin-dir ./{name}            # single
claude --plugin-dir ./a --plugin-dir ./b  # multiple at once

# Validate
claude plugin validate .

# Distribute
claude plugin install <plugin>[@marketplace] [--scope user|project|local]
```

- 変更の反映: `/reload-plugins`（skills / agents / hooks / MCP / LSP をすべて再読込）
- semver 必須（`MAJOR.MINOR.PATCH`）、`CHANGELOG.md` に記録。バージョンを上げないとキャッシュで既存ユーザーに更新が届かない
- 公式提出: https://claude.ai/settings/plugins/submit
- 開発後の監査: 公式準拠は `/plugin-audit`（Phases 1-8.5）+ 14 軸品質監査（Phase 9、[`references/quality-scoring.md`](references/quality-scoring.md) 参照）

## よくある間違い

→ [references/common-mistakes.md](references/common-mistakes.md)

## References

すべての公式ドキュメントと内部リサーチの URL は [`references/sources.md`](references/sources.md) を参照。
