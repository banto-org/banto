---
name: concept
description: |
  製品・サービス・機能の思想（哲学・世界観・なぜ作るのか）を対話で形成・尖鋭化し、North Star として CLAUDE.md に注入する。spec（設計ドキュメント）と実装（自走）の上流。
  トリガー: 「思想」「コンセプト」「世界観」「ビジョン」「哲学」「北極星」「なぜ作る」「何の敵」「誰に刺す」「思想を固めて」「コンセプト作って」。実装・spec の前に発火。
  使わない場面: 単純な実装依頼（そのままコードを書き始める）、仕様書が欲しいとき（spec を使う）。
user-invocable: true
argument-hint: "[製品/サービス/機能名 or 'light'（実験向け軽量）]"
model: opus
allowed-tools: Read Write Edit Glob Grep Bash(git:*)
compatibility: Claude Code (requires bash, git, jq)
---

# Concept — 思想形成（対話による製品哲学）

> **保存ベース（store-first）**: この skill が保存する `.ai-context/concept/...` パスは ai-context ベースを指す。SessionStart/PreCompact hook が 「ai-context ベース: &lt;absolute path&gt;」 として注入する絶対パスの配下に Read/Write すること。相対の `.ai-context/` には決して書き込まない（旧来のレガシーリポジトリにしか存在しない。不明なら `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"` で解決する）。

生成するドキュメントはユーザーの会話言語で書く（日本語で会話していれば日本語）。テンプレートのラベルはあくまで例示。

SDD（要件 → 設計 → タスク → 実装）、spec、実装はすべて「**どう作るか（実行）**」の層にあり、思想を*前提*として始まる。この skill はその一歩手前に位置し、「**なぜ作るのか / どんな世界観を投影するのか / 誰の共鳴を勝ち取るのか**」を能動的に形づくる。

```
concept (ideology, this skill) → spec (design doc) → implementation (self-driving)
   └─ output CONCEPT.md = North Star for every agent (hook-injected each session; optionally @imported into CLAUDE.md — see Intent Engineering)
```

## 基盤となるスタンス（設計方針）

- **思想は作り込める・尖らせるべき・一貫性は遡及的に構築できる。** だからこそ skill として体系化できる。
- skill の仕事は **引き出す → 尖らせる → North Star として焼き付ける**。確信の**起源は人間**にある。AI は思想を捏造しない（倫理境界）。
- 「生産コストがゼロに近づくにつれ、moat は実行から vision + empathy へ移る」（「哲学はコモディティ化できない」）。

## 発火する場面 / しない場面

| 状況 | 挙動 |
|---|---|
| 新しい製品・サービス・機能の「なぜ / 世界観」を固めたい | **Full モード**（6 Phase） |
| **クライアントの思想**を実現・尖鋭化する受託 / 大規模案件 | Full モード（クライアントを主語に） |
| AI 実験 / 探索 / 使い捨て | **Light モード**（1 行〜数行: 「何の信念を試すか」だけ） |
| CONCEPT.md が既に存在し変更が軽微 | 発火しない（既存を参照） |
| 純粋な実装 / spec 執筆 | 発火しない（spec / 自走実装へ） |

**どの段階にも最低限の思想は要る。** 実験でさえ 1 行は残す（無いと「何か試したが何も残らない」になる）。

## モード判定（Step 0）

- `$ARGUMENTS` が `light` で始まる、または文脈が実験 / 使い捨て → **Light モード**（Phase 1 と最小限の Phase 6 のみ）
- それ以外（製品 / サービス / 受託案件）→ **Full モード**（Phase 1-6）
- 迷ったら light で始め、深掘りが必要ならアップグレードする

**対話はプレーンテキストで行う（AskUserQuestion は使わない）。** 一度に 1 Phase ずつ問い、ユーザーの生の言葉を拾う。

## 対話フロー（full モード）

詳細な問いの台本は [`references/question-bank.md`](references/question-bank.md) にある。各 Phase の要点:

### Phase 1: 第一原理で WHY を掘る
ソクラテス式 + 5 Whys。**業界の慣習を括弧に入れ**、人間の事実として問い直す。
- 「なぜこれは存在すべきか？」「物理法則を除いて、何を『当然』の前提として扱っているか？」「これが無い世界では何が痛むか？」
- 出力: WHY の核（1-2 文）

### Phase 2: アーキタイプ同定（12 ブランドアーキタイプ）
ユーザーの**自然語**を採取し、ドミナント 1 型（70-80%）+ セカンダリー 1 型を特定し、**尖らせる**。型の一覧と写像手順: [`references/archetypes.md`](references/archetypes.md)。
- 例: Bezos=Sage/Ruler（データ）/ Jobs=Creator/Magician（デザイン）/ Musk=Explorer/Hero（未来）/ Anthropic=Sage/Caregiver（自由と堅牢さ）
- 出力: ドミナント型 + その型が示す思想の方向

### Phase 3: 反NG宣言（やらないことを定義する）
**思想の輪郭は、何を拒むかで定義される**（Basecamp: 成長しない / スケールしない / Exit しない）。
- 「10 年後、どうなっていたら後悔するか？」「『これは売れる』と言われても絶対に拒むことは何か？」
- 出力: 反NG宣言 3-5 個

### Phase 4: 美的シグナル（Aesthetic Signal）
記号論: 色・形・トーンが思想を符号化する。モノトーン = 誠実さ / 内部構造の露出 = 透明性 / sans-serif = 先入観の拒否 / ベゼルレス =「技術が透明になる」世界観。詳細は [`references/archetypes.md`](references/archetypes.md) の末尾。
- 出力: 帯びさせる感触・トーンを 1 語 + 理由

### Phase 5: 遡及的一貫性 + Tribe
- ピボットと過去を**一貫した一つの物語**に編む（欺瞞ではなく sensemaking。Amazon: 書店 → クラウド）
- Tribe を**デモグラフィクスでなく価値観クラスタとして**定義（「誰が『やっと分かってもらえた』と感じるか？」）
- 出力: 一貫した物語 1 段落 + Tribe 定義

### Phase 6: 結晶化 + 共感ゲート + 注入
1. **5 要素 CONCEPT.md** に結晶化（下のテンプレート）
2. **7 項目の共感ゲート**（[`references/empathy-and-ethics.md`](references/empathy-and-ethics.md)）でチェック。通らなければ Phase 2-5 に戻る
3. ストアに保存 + **CLAUDE.md への @import 注入**を提案（opt-in — Intent Engineering 参照。「no」なら SessionStart hook が代わりに CONCEPT を注入する）

## Light モード（実験向け）

Phase 1（1 行 WHY）と「何の信念を試しているか」「成功とは何か」だけを問い、最小版を `{base}/concept/CONCEPT.md` に保存する。プロジェクトが本番化したら後で full モードに昇格する。

## CONCEPT.md テンプレート（5 要素）

保存先: `{base}/concept/CONCEPT.md`

```markdown
# Concept: {product/service name}

> North Star. When in doubt, hold decisions against this. Last updated {YYYY-MM-DD} (review every 3 months)

## ① WHY (reason to exist)
{1-2 sentences. Worldview and belief. Sinek's WHY}

## ② Anti-goals (never do / never become)
- {what you refuse even if it sells}
- ...

## ③ Tribe (whose resonance to win)
{A values cluster, not demographics. "{This kind of person} feels 'finally, someone gets me'"}

## ④ Aesthetic Signal (texture / tone)
{One word + reason. e.g. "silence = a declaration of sincerity"}

## ⑤ North Star (qualitative definition of success)
{Who ends up in what state = success. Quantification comes later}

## Archetypes
Dominant: {type} / Secondary: {type}
```

## Intent Engineering（North Star 注入 — 最重要）

CONCEPT.md を**すべてのエージェントの判断フィルター**にする。2 つの要素 — 1 つは不変、1 つは opt-in:

**1. 常に保存（不変）**: CONCEPT.md は常にストアの `{base}/concept/CONCEPT.md`（store-first で解決した ai-context ベース）に保存される。下の選択に関わらずこれは変わらない。

**2. CLAUDE.md の `@import` — 先に確認（opt-in）**: CONCEPT.md を `@import` でリポジトリの CLAUDE.md にピン留めするのはチェックイン済みファイルを編集するので、実行前に確認する。プレーンテキストで問う:

> 「CONCEPT を CLAUDE.md に @import で常駐させますか？（リポジトリの CLAUDE.md に 1 行入ります）」

- **yes** → プロジェクトルートの CLAUDE.md の先頭付近に 1 行追加（Claude Code は `@import` を 5 ホップまで解決する）:
  `@<base>/concept/CONCEPT.md`（または旧来のレガシーリポジトリでは相対の `@.ai-context/concept/CONCEPT.md`）。CLAUDE.md が無ければ作成を提案（ネイティブ /init 連携）。
- **no** → **CLAUDE.md には触らない**。CONCEPT は毎セッション効く: SessionStart hook がストアの `concept/CONCEPT.md` を自動注入し、エージェントが North Star として参照する — リポジトリには何も書き込まない。

つまりリポジトリに触りたくないユーザーは **no** を選べ、CONCEPT は hook 注入で毎セッション自走する。**yes** を選べば加えて CLAUDE.md にピン留めされ、明示的でバージョン管理された記録になる。いずれにせよエージェントは常に「この実装は WHY に沿っているか / 反NG に触れていないか」を自己チェックする。

## 倫理境界（必須）

詳細: [`references/empathy-and-ethics.md`](references/empathy-and-ethics.md)。
- **偽の共感なし、ダークパターンなし**（TARES テスト準拠）
- skill は確信を**引き出す / 尖らせる**だけ。**AI は人間が持っていない思想を生成しない**
- 操作と本物の共鳴の間の線を決して越えない

## ドリフト対策

- CONCEPT.md は**ピン留めするものでなく、走らせるもの**: 3 ヶ月ごとにレビュー
- 危険信号: 意思決定から WHY の言葉が消える / 新メンバーが文化的な勘所を欠く → 再注入を促す

## パイプライン接続（次のステップ）

思想が固まったら:
- `/spec {topic}` → 思想を仕様へ翻訳する
- spec の後、そのまま実装へ進む（自走: 実装 + テスト + レビュー）
- CONCEPT.md の 5 要素は spec の判断軸（反NG、North Star）として引き継がれる

## 禁止

- ❌ AI が人間の持っていない思想を捏造する（仕事は引き出すこと）
- ❌ `AskUserQuestion` を使う（プレーンテキストで問う — このプラグインのポリシー）
- ❌ 5 要素のいずれかを「後で」と残す（採用解釈で埋め、最後に開示する）
- ❌ 共感ゲート（倫理を含む）を通さずに CONCEPT.md を確定する
