---
name: search
description: |
  ローカル AI Context（decisions / docs / 会話履歴）を Claude ネイティブに検索する — すでに蓄積された情報に対する内部検索。Web には一切触れない。
  トリガー：「前に話した」「以前の議論」「過去のチャット」「思い出して」「recall」「履歴」「経緯」「なぜこうなった」「前に決めた」「探して」。/search <query> でも呼び出し可能。
  Do not use when：外部ソース（Web / GitHub / arxiv）から新しい情報を取得するとき（research skill を使う）。
user-invocable: true
argument-hint: "[検索クエリ]"
allowed-tools: Grep Glob Read Write Edit Bash Agent
compatibility: Claude Code (requires bash, git, jq, python3)
---

# Search — 内部検索（Claude ネイティブ）

> **検索ベース（store-first）**：本スキルでの `{base}` は ai-context ベースを指す。SessionStart/PreCompact hook が「ai-context ベース: &lt;absolute path&gt;」として注入する絶対パス配下を検索する（不明な場合は `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"` で解決する）。

出力言語: 応答・検索レポートとも会話言語で書く（日本語なら `writing-ja.md` 準拠）。

## search vs research

| | `/search`（本スキル） | `/research` |
|---|---|---|
| 対象 | **内部**：`{base}/decisions/` `docs/` + 会話履歴 + `extra_docs_dirs` | **外部**：Web、GitHub、arxiv、X、公式ドキュメント |
| Web アクセス | **なし** | あり（WebSearch + research-agent） |
| 結果 | 既存ファイルの参照・要約 | `{base}/docs/research/` へ保存される新規ファイル |
| レイテンシ | fast: 秒 / deep: 分 | 分（research-agent の並列起動） |

**覚え方**：すでに持っているか否か。持っている → `search`、持っていない → `research`。

## 検索対象とデータレイヤー

| パス | 内容 | 鮮度 |
|---|---|---|
| `{base}/decisions/` `{base}/docs/` | 設計判断、報告書、リサーチ | 生ファイルを直接検索 |
| `{base}/full-combined.txt` + `sessions-cache/` | 上記 + 会話履歴（compact で失われた内容を含む）を連結したテキスト | SessionStart 日次（スロットル付き bg）+ deep 開始時オンデマンド |
| store ルートの `.store-index.db` | **store 横断 FTS5 セクション索引**（全プロジェクトの md・BM25 順位 + 行範囲。`sessions/`（checkpoint）は索引対象外 — 会話履歴は deep パスの full-combined が担う） | SessionStart / store 書き込み時に hook が自動再生成（scripts/store_index_gen.py。コミットされない派生物） |
| `{base}/search-lexicon.md` | **検索レキシコン**（概念 ↔ 訳語 / 同義語 / 略語） | deep パス成功時に追記（後述） |
| プロジェクトの `docs/` `specs/` など | `{base}/config.json` の `extra_docs_dirs` で追加 | full-combined 生成に含まれる |

## 検索手順

### Step 0: レキシコンを読む

`{base}/search-lexicon.md` が存在する場合は Read し、一致する行の語を展開に取り込む（無ければスキップ）。

### Step 1: クエリ展開（3 tier、重み付き）

次のルールでクエリを**重み付きグループ**に展開する：

1. **Tier1（×1.0）= 同義語**：日本語の同義語 + **英訳** + カタカナ表記ゆれ + 略語を同じグループに入れる（記録は英語の可能性が常にあると想定する。「漂流」→ drift）
2. **Tier2（×0.6）= 近接概念**
3. **Tier3（×0.3）= 隣接概念**：「似ているが意図が異なる」語をここに入れる（監視→監査）。拾うが、支配的にはしない
4. **疑問形を分解する**：「なぜ X は廃止されたか」→ `[X]` と `[廃止|supersede|撤廃]` を**別々の Tier1 グループ**にする（複数グループ一致のボーナスが soft-AND として働く）
5. **複合語を分割する**：「ProjectX 漂流」→ `[ProjectX]` + `[漂流|drift]`
6. 短い ASCII トークン（PR/WS/KD）はそのまま渡してよい（スクリプトが `\b` 境界を付与する）

### Step 2: fast パス（既定、秒）

ランキングスクリプトでスコアリングする：

```bash
python3 "$CLAUDE_PLUGIN_ROOT/scripts/ai_context_search_rank.py" \
  --base "{base}" --top 8 \
  --groups '[[1.0,["認証","auth","OAuth"]],[0.6,["認可"]],[0.3,["ログイン"]]]'
```

- 出力 JSON の `confident: false`（top score < 1.0）は**ゼロヒット**として扱う → Step 4 へ
- `confident: true` → Step 3 へ

### Step 2.5: 3 層取得（トークン予算の制御。ヒット過多 / 全件俯瞰のとき）

ヒットが多い、または「一覧で俯瞰したい」「経緯を時系列で」といったときは `--layered` を付け、**index → timeline → full** の 3 層で段階的に取得する（claude-mem の 3 層取得パターン。安い層から読み、必要なファイルだけ Read で開いてトークンを節約する）：

```bash
python3 "$CLAUDE_PLUGIN_ROOT/scripts/ai_context_search_rank.py" \
  --base "{base}" --top 8 --layered --index-top 5 \
  --groups '[[1.0,["認証","auth","OAuth"]],[0.6,["認可"]]]'
```

出力は `{confident, layers:{index, timeline, full}}`（`--layered` 無しの `{confident, results}` は従来どおり・互換）。各層の読み方と表示順：

1. **index（最安・まず読む）**：上位 `--index-top` 件を `path / score / terms（一致語）` の 1 行に圧縮した索引。まずこれだけ提示し、開く候補を絞る
2. **timeline（時系列の文脈）**：全ヒットをファイル名先頭の日付（`YYYY-MM-DD`）で **新しい順** に並べた列。経緯・supersede 関係の俯瞰に使う（日付の無いものは末尾）
3. **full（最後・Read 直前）**：従来の `score / path / hits` 詳細行。index と timeline で開くと決めたファイルだけを Read する

index だけで足りるなら full は開かない。経緯質問なら timeline を主に提示する。確信ヒットがあれば Step 3 へ（開くと決めたファイルだけ検証する）。

### Step 2.7: cross-store クイックパス（横断意図を検出したとき）

「他のプロジェクトで」「前にどこかで」など**現プロジェクト外**を示す語があれば、deep パスへ行く前に FTS5 セクション索引を直接引く（1ms・BM25 上位 8 件 + 行範囲）：

```bash
sh "$CLAUDE_PLUGIN_ROOT/scripts/store-query.sh" --all 認証 OAuth
```

- ヒットの**行範囲だけ**を Read（offset/limit）して Step 3 の検証へ（全文 Read しない）
- exit 1（sqlite3 / 索引不在）→ そのまま Step 5 deep の cross-store 経路へ（fail-open）
- 現プロジェクト内の絞り込み検索にも使える（`--all` を外すと既定でカレントプロジェクトに絞る）。3 文字未満の語は自動で LIKE 走査へ切り替わる

### Step 2.8: 派生記録から一次文書へ（`--related` 芋づる）

ヒットが派生記録（workspace 台帳・tasks・`[Index]`・`[Status]` など）なら、一次文書（decision）まで遡ってから答える：

```bash
sh "$CLAUDE_PLUGIN_ROOT/scripts/store-query.sh" --related <relpath の一意な断片>
```

- 出力は `→ 参照している（related:）` と `← 参照されている` の双方向エッジ
- 芋づった先の decision を Read で検証してから Step 3 へ進む（派生記録の内容だけで答えない）
- R8 実測の教訓：checkpoint / 台帳への誤着地から一次文書へ遡れず誤答した。派生記録で止めない。

### Step 3: 検証（Read して判断）

上位 3〜5 ファイルを Read し、**関連性を自分で判断**する：

- 多義語の不一致を除外する（例：「harness」が配線を意味するドキュメント）
- 自己参照を除外する（いま書いている当のドキュメント、クエリを引用しただけの評価表）
- supersede 関係を確認する（古い決定が新しい決定に上書きされていないか？）
- 派生記録に着地していないか確認する — 着地したら Step 2.8 の `--related` で一次文書へ遡る
- ヒットが `[Ref]` カード（doc_type=ref）なら実体はリモート — 中身が要るときは `research` で本文を取り込む

### Step 4: ゼロヒット時の 2 巡目（1 回だけ）

別の同義語セットで Step 1〜2 をやり直す（訳の方向を反転、略語をフルネームに展開、分割粒度を変える）。なお `confident: false` → Step 5 の deep パスへエスカレーションする。

### Step 5: deep パス（並列 haiku、分）

**トリガー**：2 巡目後もゼロヒット / 「徹底的に」「全部」 / 「他のプロジェクトで」（cross-store） / 「前に話した」（会話履歴）。履歴・cross-store クエリは fast を飛ばしてここから**開始してよい**。

0. 開始時刻を記録する（wall-clock 時間を報告する）。履歴検索ではまず full-combined を更新する：
   ```bash
   python3 "$CLAUDE_PLUGIN_ROOT/scripts/ai_context_combined.py" --project-root "$PWD" --scope full
   ```
1. **1 メッセージ内で 3〜5 個の `search-agent`（model=haiku）を並列起動**する。標準的な役割分担：
   - (a) 日本語表記ゆれエージェント：`{base}/decisions/` `{base}/docs/`
   - (b) 英語 / コード用語エージェント：同じパス
   - (c) cross-store：まず `store-query.sh --all` を直接実行する（エージェント不要・1ms）。索引が無い環境でのみ従来どおり haiku grep エージェント（`~/ai-context-store/*/decisions/` `*/docs/`）を立てる
   - (d) 会話履歴エージェント：`{base}/full-combined.txt`
2. 各エージェントには常に：正規表現パターンセット / 対象パス / **limit N（パターンごと top 15、120 文字スニペット）** / 一時ファイル出力パス `{base}/tmp/search/<run-id>-<role>.txt` を渡す。各エージェントも Grep を並列で実行させる
3. **確信度はエージェント間の候補の一致で判断する**（複数エージェントが同じファイルを浮上させたら強いシグナル。haiku の自己申告の確信度は使わない）
4. opus（メイン）が上位候補を Read 検証 → 統合する

### Step 6: レキシコンへフィードバック（deep 成功時は必須）

deep パスが正解にたどり着いたら、効いた展開を 1 行として `{base}/search-lexicon.md` へ追記する：

```markdown
漂流 ↔ drift, W1, Wasserstein   <!-- found via project search -->
```

これにより**検索すればするほど次の fast パスが決定論的に賢くなる**（git 経由でチーム共有のリコール）。
Step 7 の報告で追記の有無を必ず申告する（省略を可視化する）。

### Step 7: 報告フォーマット

```markdown
## Search results: {query}

### Related design decisions
1. **{title}** ({date}, score: X.XX)
   - Decision: {summary}
   - File: {base}/decisions/{filename}

### Related research
- {research file}: {summary}

### Conversation history (when the deep path found matches)
- {summary of matched context}

### Notes
- {supersede relations, explicit "not confident", etc.}

### Search method: {fast (ranking vN) / fast+layered (index→timeline→full) / fts5 (store-query.sh, project|all) / deep (haiku xN parallel, wall time Xs) / cross-store: {store names,...}}

### Lexicon: {追記済み — {追記した行} / 追記なし（deep 未実行 or 失敗）}
```

**確信がない**場合（しきい値を下回って終わった場合）は、推測で埋めず「確信なし」と明示する。

### ゼロ確信時の `research` への引き継ぎ（store-first の閉ループ）

deep パスまで尽くしても**ゼロ確信**（store に答えが無い）で終わった場合、ローカルに無いだけで外部にはあるかもしれない。問いが外部情報（最新動向 / ライブラリ比較 / 公式仕様など）を要するなら、`research` skill への引き継ぎを提案する（`/research <query>`）。`research` は逆向きに「まず `search`（=本スキル）を回す」ため、store-first の順序を保ったまま web へエスカレーションする閉ループになる。問いが純粋に内部履歴（「前に決めた」「経緯」）を問うものなら引き継がず、「確信なし」で止める。

## cross-store の NDA / 機密保持

- cross-store の検索結果は**セッション内の内部参照に留める**。他クライアントの具体（プロジェクト名、決定内容、人物）を現在のプロジェクトの成果物（コード、ドキュメント、コミット）へ転記しない — 書き込み側は pii-protection / egress-guard が強制する
- どの store を検索したかは常に「Search method」欄に列挙する

## データレイヤーの保守

- 手動再生成：`python3 "$CLAUDE_PLUGIN_ROOT/scripts/ai_context_combined.py" --project-root "$PWD" --scope full`
- `{base}/tmp/search/` 配下の一時ファイルは溜まったら削除してよい
