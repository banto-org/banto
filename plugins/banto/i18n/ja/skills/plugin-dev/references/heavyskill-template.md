# HeavySkill 4-component テンプレ

[arXiv 2605.02396 (HeavySkill)](https://arxiv.org/abs/2605.02396) の「並列推論 + 逐次審議」構造を Markdown スキル化したテンプレ。

plugin-audit はこの 4 ブロック（Activation Conditions / Parallel Protocol / Deliberation / Output Constraints）の有無を info 表示する。

**適用対象**: 複雑な判断 / トレードオフ整理 / 多視点分析を伴う **WORKFLOW SKILL**。
**適用しない**: 単純な utility / analysis skill（重すぎて却ってノイズになる）。

---

## SKILL.md 雛形

```markdown
---
name: {skill-name}
description: "{What it does}。HeavySkill 式 4 段階で {問題領域} を構造化分析。トリガー：「{T1}」「{T2}」。INVOKES: Agent (Task tool) で K=3-5 個の独立分析を並列起動 → deliberation で再導出。{単純なケース}では発動しない（{代替手段}を使う）。"
user-invocable: true
argument-hint: "[{入力}]"
model: opus
allowed-tools: ["Read", "Grep", "Glob", "Agent"]
---

# {Skill Name} — HeavySkill 4-component 構造化推論

## 1. Activation Conditions（発火条件）

以下の **すべて** を満たす場合のみ発火:

- [ ] {ユーザー意図条件}
- [ ] 問題に **真の分岐** がある（採用解釈で進められない）
- [ ] {ドメイン固有の前提}
- [ ] ゴール分岐がある（受け入れ基準が変わる、影響範囲のオーダーが違う）

**発火しない**: {代替 skill / 単純ケースの判定基準}

## 2. Parallel Protocol（並列推論）

`Task tool` で K=3〜5 個の独立分析エージェントを **同一メッセージで並列起動**。

各 worker は **異なる視点** を持つ（同一プロンプトの並列ではない）:

```
[独立視点 X / Y]
問題: {ユーザーの入力}

以下の観点だけで分析（他視点は無視）:
- 視点 1: {視点 1 の名前と範囲}
- 視点 2: {視点 2 の名前と範囲}
- 視点 3: {視点 3 の名前と範囲}
- (必要なら 4-5 視点まで)

出力:
## 推奨案
## 根拠 (3 点)
## 棄却した代替案 + 理由

他視点との対立は無視して、自分の視点だけで結論を出すこと。
```

**重要原則**:
- 各 worker は他 worker の出力を参照しない（独立性確保）
- 温度高め（多様性）
- 異なる視点で割り当て（同一プロンプトの並列ではない）

## 3. Deliberation Prompt（逐次審議）

K 個の出力をメイン session で deliberation。**多数決ではなく再導出**:

```
[Deliberation]
K=N 個の独立分析が出揃いました。以下を実行:

1. 視点間の対立を抽出
2. 対立が「真のトレードオフ」か「片方優先か」判定
3. 全視点を満たす **新しい解** を再導出（含まれていなくても OK）
4. 再導出が不可能なら最多視点を満たす案を選択
5. リスク・未確認事項を「未確認:」で明示
```

HeavySkill の核心: 多数決 (Vote@K) ではなく、**新解の生成 (HP@K > Pass@K)**。

## 4. Output Constraints（出力制約）

最終出力は **必ず** 以下の構造:

\`\`\`markdown
## 結論
{1 文で明確な推奨}

## 根拠（3 つ以内、優先度順）
1. ...
2. ...
3. ...

## 検討した選択肢（並列分析の集約）
| 案 | メリット | デメリット | 可逆性 |
|----|----------|------------|--------|
| A  | ... | ... | 高/中/低 |

## 棄却した案と理由

## 未確認 / リスク
- 未確認: ...
- リスク: ...

## 次のアクション
- [ ] {具体的な手順}
\`\`\`

### 禁止事項

- 「場合によります」で逃げない
- 全選択肢を並列に並べて終わらない
- 「ご検討ください」で丸投げしない
- 不確実な場合は「未確認:」プレフィックス
```

---

## 軽量モードを併設すべきか

問題が「中程度の複雑さ」なら K=1 で十分なケースが多い。Activation Conditions で「中複雑度」も拾うなら、軽量モードを併設:

```markdown
## 軽量モード（K=1, deliberation スキップ）

問題が中程度なら K=1 でも OK。テキストで確認:
- 「並列分析（重め、5 worker）」 vs 「単独分析（軽量）」
- デフォルト: 単独分析
```

---

## 適用例

- `research` skill — 外部調査の並列 fan-out（research-agent を 5-10 並列）
- `spec` skill — 大規模設計（旧 design-first）
- `architect` agent — 複雑なアーキテクチャレビュー
- （旧 `deep-think` が代表例だったが v5.21.0 自走ハーネス原則で廃止。難判断は自走で深く推論）

`plugin-dev` の Step 2.5 で AI が「この skill は 4-component が適切」と判定した時に提案する。
