# Layer 3 3 点セット — skill + rule + hook scaffold

新規 skill を作る時、Layer 3 ハーネスエンジニアリングの枠組みに沿って **skill + rule + hook の 3 点セット** で設計する。skill だけで完結させると確率的遵守の天井に当たり、運用後に「rule で書いたのに守られない」事故が起きる（AGENTIF: tool constraint 43.2%）。

## いつ 3 点セットを使うか

skill が以下のいずれかを含むなら、対応する rule と hook も検討する:

| skill の性質 | rule 候補 | hook 候補 |
|------------|----------|----------|
| 特定ファイル種別のみで意味を持つ手順 | path-scoped rule（操作 context の明示） | PreToolUse Write|Edit (該当 path matcher) |
| 「必ず X してから Y する」順序制約 | 行動原則 rule（手順の意図） | PreToolUse でチェック、未実行ならブロック |
| 危険操作（git push / .env 露出 / rm -rf） | 注意喚起 rule（人間可読の警告） | PreToolUse Bash / permissions.deny |
| 外部 API 呼出 | 認証・rate-limit 注意 rule | PostToolUse でログ・監視 |

skill のロジックが**全て上位概念** で「ファイル種別やコマンド種別と無関係」なら 3 点セットは過剰。skill 単独でよい。

## 各コンポーネントの役割（4 区分マトリクス再掲）

```
                  rule (paths:)      skill (description)     hook (matcher + exit 2)
                  ────────────────────────────────────────────────────────────────
注入トリガー       path 一致           description 一致         tool 一致 (deterministic)
強制力            なし（確率）         なし（確率）             あり（exit 2 でブロック）
表現粒度          宣言的（指針）       手続的（手順）           手続的（前後チェック）
遵守率（研究）    43%（AGENTIF）       中（skill-routing 精度） 90-100%（AgentSpec）
```

**選択原則**:
1. **取り返しがつかない / 法的影響 / セキュリティ** → hook 必須（rule では弱い）
2. **特定ファイルで意味を持つ context** → path-scoped rule（常時注入を避ける）
3. **手順そのもの・複数ステップ** → skill（rule で書くと冗長）

## scaffold 手順（推奨）

### Step 1: skill の本質を分類

```
質問:
- この skill は何を「変えない」ようにしたいか？（→ hook 候補）
- どんなファイル種別 / コマンド種別と紐づくか？（→ path-scope or hook matcher）
- 説明文（rule）と手順（skill）を分けて書く意味があるか？
```

### Step 2: 3 ファイルを同時に生成

#### rule template（path-scoped 推奨）

`templates/rules/{topic}.md`:

```markdown
---
paths:
  - "**/*.{ext1,ext2}"     # 関連ファイル種別
  - "src/{domain}/**"      # 関連ディレクトリ
---

# {Topic} ルール

{topic} 編集時に適用される原則（path-scoped で条件注入）。

- {原則 1}
- {原則 2}

詳細手順は skill (`/skills/{skill}/SKILL.md`) を参照。
hook での deterministic enforce は `hooks/{topic}-guard.sh`。
```

#### skill template（手順）

`skills/{skill}/SKILL.md`:

```markdown
---
name: {skill}
description: "..."
allowed-tools: Read Write Edit Bash Agent
---

# {Skill}

## Layer 3 関連ファイル
- 行動原則: `templates/rules/{topic}.md`（path-scoped）
- 強制チェック: `hooks/{topic}-guard.sh`（PreToolUse）

## 実行手順
...
```

#### hook template（PreToolUse / PostToolUse）

`hooks/{topic}-guard.sh`:

```sh
#!/bin/sh
# {Topic} Guard Hook — deterministic enforce
# rule（templates/rules/{topic}.md）の確率的遵守を補強。

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# path 判定
case "$FILE_PATH" in
    *.ext1|*.ext2|src/{domain}/*)
        # 違反チェック
        if {違反条件}; then
            echo "[Hook] {違反内容}" >&2
            exit 2  # ブロック
        fi
        ;;
esac
exit 0
```

`hooks/hooks.json` に登録:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/{topic}-guard.sh", "timeout": 3 }
        ]
      }
    ]
  }
}
```

## 不要な 3 点セットを避ける判断

以下のケースは**最小構成（skill 単独 or rule 単独）で十分**:

- 軽量 utility skill（typo 修正、format 変換、status 表示）— rule も hook も不要
- 1 ファイル種別の skill で hook 化が技術的に困難（プロンプト解析が必要 etc.）— skill + path-scoped rule のみ
- 概念的・教育的な行動原則（「結論を先に」など）— rule のみ（hook 化不能）

判断に迷ったら **skill のみで作成 → 運用後に必要が出たら rule / hook を追加** で OK。3 点セットを義務化しない（過剰設計を回避）。

## scaffold チェックリスト

新規 skill 作成時に以下を自問:

- [ ] この skill は特定ファイル種別と紐づくか？ → YES なら path-scoped rule を併設
- [ ] 「必ず X」「絶対 Y しない」を含むか？ → YES なら hook 化を検討
- [ ] permission.deny で表現できる禁止か？ → YES なら hook より permissions が軽い
- [ ] skill description は ≤50 語で Use when 形式か？（Axis 3）
- [ ] rule に `paths:` を付けて常時注入を回避したか？（Axis 9）
- [ ] hook を作るなら hooks.json に登録したか？

## plugin-audit との連動

3 点セット作成後、`/plugin-audit` を実行して検証する。確認軸（Axis 9 の `rule_should_path_scope` / `rule_hard_constraint`、Axis 5 の HeavySkill 誤適用など）の正本は `skills/plugin-audit/references/scoring.md`。
