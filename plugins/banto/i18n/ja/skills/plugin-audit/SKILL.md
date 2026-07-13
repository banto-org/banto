---
name: plugin-audit
description: |
  既存の Claude Code プラグイン、または単一スキルを、公式ベストプラクティスと突き合わせて監査し、不整合を検出して修正を提案する。引数にプラグインパスまたはスキルパスを渡せる（スキル単位監査）。
  トリガー: 「プラグイン監査して」「この skill の品質チェック」「SKILL.md をベストプラクティスと突き合わせて」「15 軸で見て」。/plugin-audit でも呼び出し可能。監査自体は read-only であり、修正の適用にはユーザー承認が必要。
  使わない場面: ハーネス全体をシステムとして監査する場合（harness-audit）、プラグインを生成 / リファクタする場合（plugin-dev）、skill 単体をコンテキストエンジニアリング視点（情報の最小性等）で監査したい場合（skill-audit）。
user-invocable: true
argument-hint: "[eval|verify|fix|global] [プラグインパス または skills/<name>（省略時はカレントディレクトリ）]"
allowed-tools: Read Write Edit Glob Grep Bash Agent
compatibility: Claude Code (requires bash, git, jq)
---

# Plugin Audit — プラグイン公式ベストプラクティス監査

出力言語: 応答は会話言語で書く（日本語なら `writing-ja.md` 準拠）。

> **メタ監査の責務分担**:
> - **plugin-audit（この skill）** = プラグイン / 単一スキルの**品質**監査（公式準拠 + 15 軸構造評価）。引数に `skills/<name>` を渡すとスキル単位監査になる。
> - **skill-audit** = 単一 skill に絞った**コンテキストエンジニアリング**監査（情報の最小性 / 人間専用情報の混入 / 構成の分担 / 実行モデル指定 / コンテキスト効率 / 想定 AI 整合 / 決定論との分担の 7 軸）。plugin-audit の 15 軸品質監査より狭く、実行に必要な情報だけを渡せているかに絞る別 skill。
> - **harness-audit** = ハーネスの**全体システム**監査（思想整合 / 死蔵機能 / 鮮度 / インストールポリシー / Claude 機能整合）。「スキル品質は完璧だが機能が死蔵 or ドリフトしている = それでも壊れている」を拾う別レイヤー。
> - **plugin-dev** = 生成とリファクタ（監査は plugin-audit に委譲）。

引数 `$ARGUMENTS` はプラグインパスを指定する。省略時はカレントディレクトリまたは `plugins/` 配下を探す。

公式根拠: https://code.claude.com/docs/en/plugins-reference

## 監査手順

### Phase 1-8.5: 公式準拠チェック

各 Phase の詳細は [`references/audit-phases.md`](references/audit-phases.md) を参照:

- **Phase 1**: ディレクトリ構造
- **Phase 2**: plugin.json（experimental.* の配置を含む）
- **Phase 3**: SKILL.md frontmatter（公式 18 フィールド、文字数キャップ 1,024/1,536）
- **Phase 4**: SKILL.md 本文（500 行以内）
- **Phase 5**: hooks/hooks.json（29 イベントタイプ、5 hook タイプ）
- **Phase 6**: .mcp.json（${CLAUDE_PLUGIN_ROOT} / ${CLAUDE_PLUGIN_DATA}）
- **Phase 7**: commands/*.md（skills に統合）
- **Phase 8**: 非公式 / 実験的コンポーネント
- **Phase 8.5**: Plugin agent の制限（hooks / mcpServers / permissionMode は無視される）

### Phase 9: 15 軸品質監査

Phase 1-8.5 は「動くか」を見る公式準拠チェック。Phase 9 は **15 軸品質監査**: 静的構造軸（監査スクリプトが計算）＋判定軸（独立サブエージェントで実行 — Reviewer = Fresh Agent）。

詳細:
- 評価基準（15 軸の定義）: [`references/scoring.md`](references/scoring.md)
- 機能検証（`verify` サブコマンド — skill が発火したあと、claim 通りに実際に生成するか）: [`references/verify.md`](references/verify.md)

**15 軸**（static = 監査スクリプトが計算 / agent = 独立サブエージェントが判定）。各軸の定義は [`references/scoring.md`](references/scoring.md) が正本 — ここでは再掲しない。static 軸は 1/2/3/7/9/10/11/12/14/15（+5/6 の検出材料）、agent 軸は 4/6/7-semantic/8/12b/13/14-semantic。軸とスクリプトの対応は下記コマンド一覧を参照。

**静的軸 — スクリプトを実行**:

```bash
# Static structural audit (Axes 1/2/3/5-detect/7/9/10/14 + material for 6)
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-collect.sh <plugin_dir> | \
  ${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-report.sh

# Disambiguation matrix (Axis 6 static, cross-skill computation)
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-matrix.sh <plugin_dir>

# Usage (Axis 11, active/mentioned/dormant/likely-trim classification)
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-usage.sh <plugin_dir> [since_days]

# Permission minimality (Axis 12 static candidates: declared allowed-tools vs evidenced usage)
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-permissions.sh <plugin_dir>

# Subtree assets (Axis 14 hygiene + Axis 2 slimming, extended to references/ + nested files)
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-assets.sh <plugin_dir>

# Interface fidelity (Axis 1: argument-hint surfaces the skill's real subcommands)
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-interface.sh <plugin_dir>

# Shape-up triggers (Axis 2 weight + cross-skill near-dup; thresholds = review triggers, not gates)
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-shapeup.sh <plugin_dir>

# Cross-skill reference consistency (Axis 15: same store path referenced with divergent spellings)
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-consistency.sh <plugin_dir>

# ODD schema lint (Axis 10 extension: odd.yaml structural validity — required / unknown keys / autonomy range / skill match)
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-odd.sh <plugin_dir>
```

- `plugin-audit-collect.sh`: skills / agents / templates/rules / commands / hooks をスキャンし TSV を出力
- `plugin-audit-report.sh`: TSV を Markdown の静的監査レポートに変換
- `plugin-audit-matrix.sh`: cross-skill 計算（語彙重複 / 双方向参照 / 一方向参照 / 分類プレフィックス分布）を Markdown で出力
- `plugin-audit-usage.sh`: 過去 N 日の git log + {base} 言及から使用度を分類（Axis 11）
- `plugin-audit-permissions.sh`: skill ごとの `allowed-tools` vs 実使用エビデンスを照合 — 過剰付与（宣言したが未使用）と宣言漏れ（idiom で使うが未宣言）を flag。Axis 12 の agent パス向けの idiom ベース候補（Axis 12）
- `plugin-audit-assets.sh`: 各 skill のサブツリー（`references/` + ネスト）を走査し、目録 / 不要ファイル / orphan / **3b dangling 参照（存在しない `references/X.md` を指すポインタ — markdown リンクだけでなくコードスパン/散文も対象。クロス参照とプレースホルダは除外）** / 重複 / Axis 14 hygiene を出す（collect.sh が SKILL.md しか見ない穴を埋める Axis 14 + Axis 2 拡張。詳細は scoring.md Axis 14）
- `plugin-audit-interface.sh`: argument-hint が skill の実サブコマンドと一致するかを検査（Axis 1 拡張。詳細は scoring.md Axis 1）
- `plugin-audit-shapeup.sh`: 軽量化トリガー（重量 + 死蔵 + 近似重複）を出す。閾値はゲートではなくレビュー対象（Axis 2 拡張。詳細は scoring.md Axis 2）
- `plugin-audit-consistency.sh`: 全 skill 横断で「同一 store パスを別の綴りで参照する乖離」をクラスタリング検出（Axis 15）。store-map-lint がマニフェスト対照なのに対し、こちらは**マニフェスト無しで綴り不一致そのものを炙り出す**（接頭辞 `{base}` への正準化を推奨）。`--strict` で乖離時 exit 1
- `plugin-audit-odd.sh`: 全 skill の `odd.yaml` を `templates/odd/odd.schema.yaml` で検証（Axis 10 拡張）— required キー欠落 / 未定義キー（`additionalProperties:false`）/ autonomy 範囲外（L4/L5）/ skill 名↔ディレクトリ不一致 / `schema_version` を deterministic に検出。**並走セッションの revert や貼り戻しで odd が pre-schema 形へ崩れるのを CI/SessionStart で弾く**（diff 目視では見落とす構造崩れを機械検知）。`--strict` で違反時 exit 1。パス綴りの skill 間ドリフトは Axis 15 が担当（役割分担）

**判定軸 — サブエージェントで実行**（Reviewer = Fresh Agent: 判定はメインセッションの self-evaluation bias を避けるため独立した `general-purpose` サブエージェントに委譲）:

各判定軸の詳細定義は scoring.md の対応する Axis 節を参照（Axis 4 ルーティング精度 / 5 HeavySkill 適用 / 6 境界曖昧さ / 7 semantic 汎用性 / 8 rule 外部化 / 12 権限最小性 / 13 封じ込め / 14 semantic hygiene）。

軽量なデフォルト監査は静的軸 + 安価な単一パスの Axis 12/13 を回す。`eval` / `verify` / `global` / リリース前監査ではすべての判定軸を回す。

## スキル単位監査（単一スキルモード）

引数がプラグインディレクトリではなく `skills/<name>` のような**単一スキルディレクトリ**の場合、その skill のみを監査する:

```bash
# Usage of a single skill
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-usage.sh --skill skills/<name> [since_days]
```

`collect.sh` / `report.sh` はプラグインディレクトリを前提とするため、スキル単位監査は次の手順で代替する:

1. 引数が単一スキルかプラグインかを `skills/` サブディレクトリの有無で判定する（あればプラグイン、無ければ単一スキル）
2. 対象の `SKILL.md`（+ `references/` があれば）を Read する
3. `usage.sh --skill` を実行して使用度（Axis 11）を得る
4. Axis 1/2/3/5/12 は、Read した内容を [`references/scoring.md`](references/scoring.md) の各軸定義と突き合わせて Agent が判定する
5. Critical → Warning → Info の順でレポート形式（下記）にまとめる

**サブコマンド（モード）**:

| サブコマンド | 内容 | コスト |
|-------------|------|-------|
| `plugin-audit` | Axis 1+2+3+5+6+7-local+8-static+12-static（既定。shapeup トリガーもここに出る）| 数秒 |
| `plugin-audit eval` | Axis 4 ルーティング（tier 別 sweep は `--tiers haiku,sonnet,opus`）+ 7-semantic（並列 Agent）| 数十秒 |
| `plugin-audit verify` | 機能検証 — Tier A/B の skill を sandbox で end-to-end 実行し、その `verify-cases.yaml` に対して検証する（[`references/verify.md`](references/verify.md)）| 数分 |
| `plugin-audit fix` | Agent が修正提案 → 対話承認 + Axis 8 rule 外部化 + **軽量化提案**（既定レポートの shapeup トリガーを Agent がレビュー → 分割 / 抽出 / rule 化 / 統合。閾値超過は失敗でなくレビュー対象）| 数十秒 |

`global` 修飾子（任意サフィックス）は公開配布基準（言語 / 文化 / ライセンスチェック ON）に切り替える。改善提案の対話フローは下記「修正フロー」を参照（review-then-fix、description は決して自動書き換えしない。判定は Reviewer = Fresh Agent 原則に従う）。

## 監査レポート形式

```markdown
# Plugin Audit Report: {plugin-name}

## Critical (affects operation)
- [file]: [issue] → [fix]

## Warning (non-compliant with official docs but works)
- [file]: [issue] → [fix]

## Info (recommendations)
- [file]: [issue] → [fix]

## Statistics
- Skills: N
- Hooks: N
- Average description length: N chars
- SKILL.md over 500 lines: N
- description over 1,024 chars: N / over 1,536 chars: N
- HeavySkill 4-component adopted: N
- skill classification prefix adopted: N
```

（レポートはユーザーの会話言語でレンダリングする。）

## 修正フロー

監査を実行しレポートを生成したあと（手順は audit-phases.md の Phase 1-8）、以下の対話フローで修正する。

### Step 1: 結果をユーザーに提示 + 修正を確認

```
After displaying the audit report above:

"The following issues were detected:
 - Critical: N
 - Warning: N
 - Info: N

 Fix them in one batch?
 [A] Fix everything
 [B] Fix Critical only
 [C] Review each fix one by one
 [D] Do not fix (report only)"
```

選択肢をテキストで提示し確認する。（ユーザーが日本語で会話している場合は、選択肢を日本語で提示する。）

### Step 2: 修正を適用

ユーザーが承認した項目を順に適用する:

1. `when_to_use` フィールドを削除 → `description` に統合
2. 非公式フィールドを削除
3. 絶対パスを `${CLAUDE_PLUGIN_ROOT}` に置換
4. 500 行超の SKILL.md を `reference.md` に分割
5. `.mcp.json` を生成（既存の mcp-servers がある場合）
6. 未登録 hook を hooks.json に登録

各修正で diff を表示しユーザー確認を取る（選択肢 A は一括、選択肢 C は個別）。

### Step 3: 修正後に再検証

すべての修正完了後、再度監査を実行し残課題を表示する。

## 監査対象の決定

`$ARGUMENTS` の解釈:
- 省略 → カレントディレクトリがプラグインならそれを監査、そうでなければ `plugins/*/` 全体を監査
- パス指定 → そのパスを監査
- プラグイン名 → `plugins/{name}/` を監査

## 禁止事項

- **ユーザー承認なしの自動修正禁止**（破壊的変更になりうる） — 監査自体が read-only だからこそ自然言語発火が安全
- **バックアップなしの修正禁止**（git に未コミットなら警告する）

## 参照

- Plugins（公式）: https://code.claude.com/docs/en/plugins-reference
- Skills: https://code.claude.com/docs/en/skills
- Hooks: https://code.claude.com/docs/en/hooks
