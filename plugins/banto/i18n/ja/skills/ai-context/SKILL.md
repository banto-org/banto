---
name: ai-context
description: |
  AI コンテキスト管理: 決定ログ / チェックポイント / タスクファイル（tasks.md）編集 + 次タスクナビ + Phase 完了 / ドキュメント振り分け / メモ / ナレッジ昇格 / store ブートストラップ + 健全性診断 + 常設許可（grants）管理。内部検索は `search` skill が所有する。
  トリガー: 「決定」「設計判断」「保存」「チェックポイント」「compact」「clear」「タスク」「TODO」「Phase」「続き」「次のタスク」「続きやって」「ドキュメント整理」「散らかってる」「除外」「動かさないで」「無効化」「メモして」「メモに残して」「書き留めて」「この会話を要約して保存」「ナレッジにして」「ナレッジ昇格」「下書き一覧見せて」「教訓として残して」「store を作って」「ローカル固定」「健康診断」「常設許可」「許可設定」
  使わない場面: 既に格納済みのコンテキスト検索（`search` skill を使う）や外部ソースの調査（`research` を使う）。実装中の素の「やって」「進めて」は自走（直接動く）を意味し、タスク修飾付きのフレーズ（「次のタスク」「続きやって」）のみが次タスクナビへルーティングされる。セッション状態の保存は `save-checkpoint`、スコープ用に git worktree / ブランチを切り替えるのは `ws` であって本 skill ではない。
allowed-tools: Read Write Edit Glob Grep Bash Agent
argument-hint: "[bootstrap|local|doctor|sort|next|phase-done|ignore|tasks|migrate|memo|knowledge]"
compatibility: Claude Code (requires bash, git, jq)
---

# AI Context

> **保存ベース（store-first）**: `{base}` は SessionStart/PreCompact hook が注入する ai-context ベースの絶対パス。常にその配下へ Read/Write する（in-repo `.ai-context/` は廃止済み — 検知時に store へ非破壊自動移行される。手動では使わない）。不明なら `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"` で解決する。
>
> **出力言語**: 生成する成果物はユーザーの会話言語で書く。`references/` の日本語テンプレートは雛形にすぎず、見出し/ラベルは会話言語へ翻訳する。

## サブコマンドルーター（明示的なユーザー呼び出し）

`$ARGUMENTS` の最初のトークンをサブコマンドとして解釈し、対応する references/ ファイルを Read してその手順に従う。

| サブコマンド | 役割 | 詳細 |
|---|---|---|
| `bootstrap` | store の作成 / 登録 + 仮ローカル（`ai-context-local`）→ store 移行（init を吸収） | 下記「store ブートストラップ」 |
| `local` | この repo をローカル固定（mapping `local:true`。bootstrap / 移行で GitHub へ送らない） | 下記「ローカル固定」 |
| `doctor` | 健全性診断（status 統合・書き込みなし。store health lint + 横断の移行ステータス〔中央未昇格プロジェクト〕を呼ぶ） | `references/doctor.md` |
| `sort` | `{base}/` 内の誤配置ファイルを対話的に振り分け（書き込みあり） | `references/sort.md` |
| `sort project` | プロジェクト全体の散在ドキュメントを整理 | `references/sort.md` |
| `next` | 次の未完了タスクを特定し実装まで完遂 | `references/task-lifecycle.md` |
| `phase-done [N]` | Phase 完了チェック + 検証 + アーカイブ | `references/task-lifecycle.md` |
| `ignore` | scaffold 抑止パスを管理（書き込みあり） | `references/ignore.md` |
| `tasks split` | tasks.md を Phase 単位で分割 | `references/task-lifecycle.md` |
| `migrate [path\|--all]` | プロジェクトの ai-context を中央 store へ移行 | `references/setup.md` |
| `memo [text]` | 会話 / 指定内容を `[Memo]` ドキュメント化（旧 `memo` skill を内包） | 下記「メモ（`memo`）」 |
| `knowledge [list\|promote\|<topic>]` | ナレッジ下書きの一覧 / 昇格 / 新規作成（旧 `knowledge` skill を内包） | 下記「ナレッジ（`knowledge`）」 |
| `ref [場所/URI]` | 外部文書の所在カードを `docs/refs/` に登録（「ここにある」でも発火） | 下記「所在登録（`ref`）」 |

引数が空または不明な場合は使い方を表示する。

**自然言語からの発火**: 明示サブコマンドに加えて、文脈から自動ルーティングする: 「続き」「次」「次のタスク」「進めて」 / "continue", "next", "next task", "go ahead" → `next`; 「ドキュメント整理」「散らかってる」 / "organize the docs", "it's a mess" → `sort project`; 「Phase 完了」 / "phase done" → `phase-done`; 「メモして」「書き留めて」「この会話を要約して保存」 → `memo`; 「ナレッジにして」「ナレッジ昇格」「下書き一覧」「教訓として残して」 → `knowledge`; 「store を作って」「ai-context-store をセットアップ」「GitHub に上げたい」・SessionStart hook の bootstrap 案内 → `bootstrap`; 「この repo はローカルだけで」「GitHub に上げないで」「ローカル固定」 → `local`; 「健康診断」「健全性チェック」「状態を見せて」「何があるか教えて」「未移行を確認」「移行できてないもの」「移行状況」 → `doctor`; 「このリポジトリでは PR 作成を許可して」「本番作業を許可」「push を常設許可」「常設許可」「許可設定」 → 「常設許可（grants）」。

**中央 store 運用（チーム / 複数プロジェクト）**: 中央 store の集約・同期・チーム運用（セットアップ → 移行 `migrate` → 参照 → push）の end-to-end 手順は [`references/central-store-guide.md`](references/central-store-guide.md) にある。

## store ブートストラップ（`bootstrap`）

SessionStart hook は未登録・中央 store 無しの repo で、ブロックせずに `~/ai-context-local/<project>/`（store と同一構成の仮ローカル）を即用意し 1 行通知する（黙って GitHub backed store は作らない）。`bootstrap` は**この仮ローカルを本物の store へ後追い移行**する手番。hook は会話できないため、実際の対話はここで進める。**3 択を 1 つの会話**で確認する（モーダルは使わず、普通の文章でひとつずつ聞く）:

1. **既に GitHub に ai-context-store がある場合**: repo を `org/name` で確認 → 登録 + 仮ローカル移行を 1 コマンドで:
   ```bash
   sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-context-store-init.sh" bootstrap <org>/<name>
   ```
2. **無ければ新規作成する場合**: どの org（または GitHub ユーザー名）に置くか確認 → private 固定で作成 + 移行を 1 コマンドで:
   ```bash
   sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-context-store-init.sh" bootstrap <org>
   ```
   `gh repo create --private` で作成し、選んだ org を `~/.claude/banto-store-target.conf` に保存する（2 回目以降は org 保存済みのため作成可否のみ確認・org 再入力不要）。

`bootstrap` は登録/作成のあと、この repo に仮ローカル（`ai-context-local/<project>`）があれば **store へ追加優先で移行**する（既存は上書きせず、衝突は確認）。移行後は mapping の仮ローカルエントリが消え、次回 SessionStart から store の絶対パスが注入される。

> **interface（WT-A）**: `ai-context-store-init.sh bootstrap [<org/name>|<org>]` が register-or-create + 仮ローカル移行を内包。ローカル固定は `local` サブコマンド。legacy フラグ `--create` / `--register` / `--org` も利用可。

いずれの分岐でも、登録が済めば次回 SessionStart から「ai-context ベース: &lt;絶対パス&gt;」が store 側の絶対パスとして注入され、decisions / docs / tasks を store へ書けるようになる。org を保存だけしたい時は `--org <org>`。既存の repo 内 `.ai-context/` は resolver の解決対象ではなく、scaffold が検知時に store へ非破壊自動移行するため、`migrate` の明示実行は必須ではない（今すぐ揃えたいときだけ使う）。

## ローカル固定（`local`）

GitHub に上げず**ローカル限定**で管理したい repo を固定する。mapping の該当 project に `local:true` 相当のマーカーを立て、以後 `bootstrap` や移行で GitHub へ送られないようにする。

```bash
sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-context-store-init.sh" local
```

固定後はこの repo の ai-context が `~/ai-context-local/<project>/` のまま常駐し、`bootstrap`・移行はスキップされる。解除したくなったら `bootstrap` で改めて store へ移行する。

> **interface（WT-A）**: `ai-context-store-init.sh local [--cwd <dir>]` が mapping の該当 project に `local:true` をセットする。

## 常設許可（grants）

repo 単位の常設承認を `{base}/meta/grants.json` に記録する（「このリポジトリでは PR 作成を許可して」「本番作業を許可」「push を常設許可」で発火）。書き込み後は変更を `decisions/` に 1 行記録することを推奨する。

キーは `pr_create`（`gh pr create`）/ `push_feature`（feature ブランチへの push）/ `prod_ops`（本番環境操作）。値は `allow`（常設承認・以後確認不要）/ `deny`（常時 block・誤許可の明示的な拒否に使う）/ `confirm`（既定・毎回確認）。`allow`/`deny` は `release-guard.sh`（`pr_create`）と `prod-guard.sh`（`prod_ops`）が決定論で参照する。

期限付き許可（例: 1 週間だけ許可）も書ける。値をオブジェクト `{"value": "allow", "until": "YYYY-MM-DD"}` にすると、`until` の翌日から自動的に `confirm`（毎回確認）へ戻る — `deny` へは倒れない。

```json
{"schema_version": 1, "grants": {"pr_create": "allow", "prod_ops": {"value": "allow", "until": "2026-07-17"}}}
```

## 決定の保存（自動保存 / 形式 / シークレット）

詳細: [`references/decisions.md`](references/decisions.md)

- **いつ**: 設計判断が発生した瞬間（コミットを待たない）。保存する＝設計方針 / 技術選定 / アーキ変更 / トレードオフ / 根本原因。保存しない＝単純実装 / typo / 事実回答のみ。
- **どこ**: `{base}/decisions/YYYY-MM-DD-HHMMSS_{topic-slug}_{github-account}.md`（PreToolUse hook が推奨名を注入; 旧 `YYYY-MM-DD_NNN_` 形式も有効）。
- **形式**: 軽量（タイトル + 判断）/ 完全（出発点 / 選択肢 / 決め手 / 不採用理由 / **フリクション** / **学んだこと**）。フリクションと学びが組織学習の核。
- **シークレット**（鉄則）: `sk-*` / `ghp_*` / `Bearer *` / `.env` 値を decisions / チェックポイントに書かない → `{SECRET}` に置換。露出時は即 **revoke / rotation**（チャット履歴に残る）。

## 所在登録（`ref`）— 外部文書の所在カード

外部にある文書（SharePoint / ファイルサーバ / URL / store 外のローカルファイル）の**所在と相関だけ**を
`{base}/docs/refs/[Ref] <名前>.md` に 1 枚で登録する。本文はミラーしない — 中身まで検索したい文書は
research skill で本文を `docs/research/` へ取り込む。
発火語：「ここにある」「この場所を覚えて」「所在登録」— また **Claude 自身が作業中に外部文書を読んで根拠に使ったとき**は、会話の副産物として同カードを自発的に作成・更新する。

```markdown
---
title: <人間が読む名前>
source: sharepoint | fileserver | url | local
uri: <https://… / smb://… / /Volumes/…>
fetched: <YYYY-MM-DD 最後に実物を確認した日>
related:
  - <decisions/… や docs/… — 関係する store 文書（プレフィックスで可）>
---
# <名前>

<要旨 2〜3 行（必須）。何のための文書で、どの作業と関係するか。>
```

- frontmatter（`source` / `uri` / `fetched` / `related`）が構造メタデータの確定仕様。
- **要約 2〜3 行は必須**：検索でヒットするのはカードの要約だけであり、タイトル + URL だけのカードは中身が永遠に検索に載らない。
- `related:` は決定論抽出され、台帳の `references` 関係 + 検索 db の refs テーブルになる。
  芋づるは `sh "$CLAUDE_PLUGIN_ROOT/scripts/store-query.sh" --related <断片>`（→ 参照先 / ← 被参照）。
- 正本は常に外部（uri 先）。カードは「どこにあって何と関係するか」だけを持つ。
- 一括棚卸し（ディレクトリ走査で自動生成）は `scripts/ref_scan.py`（Excel はシート一覧 + シート間参照付き。要約欄が空のカードには「(要約未記入 — 検索に載らない)」のプレースホルダが出る — 見つけたら埋める）。

## メモ（`memo`）

会話 / 指定内容を `[Memo]` プレフィックス付きドキュメントとして `{base}/docs/` に保存する（「メモして」「書き留めて」「この会話を要約して保存」でも発火）。メモの*本文*はユーザーの会話言語で書く。セクション見出し（`## Content` / `## Topics discussed` 等）は固定の構造マーカーであり翻訳しない。

引数なし → 会話要約を `{base}/docs/[Memo] session-summary-{YYYY-MM-DD}.md` へ。引数あり → `$ARGUMENTS` の内容を `{base}/docs/[Memo] {slugified argument}-{YYYY-MM-DD}.md` へ。穴埋めテンプレートと文体規約: [`references/doc-templates.md`](references/doc-templates.md)。

## ナレッジ（`knowledge`）

ナレッジ下書き（`{base}/docs/knowledges/drafts/`）をレビュー・昇格し、正式なナレッジエントリへ整理する（「ナレッジにして」「下書き一覧見せて」「教訓として残して」でも発火）。応答・記述はユーザーの会話言語で行う。

`$ARGUMENTS` の最初のトークンでモード判定: 引数なし/`list` → 下書き一覧、数字/`promote` → 昇格、トピック文字列 → 新規作成。手順・穴埋めテンプレート・下書き自動保存 hook の説明: [`references/doc-templates.md`](references/doc-templates.md)。構造の正本: [`references/directory-structure.md`](references/directory-structure.md)（昇格先 = `{base}/docs/knowledges/{topic}.md`、下書き = `{base}/docs/knowledges/drafts/{topic}.md`）。

## ディレクトリ構造 / プレフィックス

詳細・正本: [`references/directory-structure.md`](references/directory-structure.md)（フォルダ → 書く skill/hook → prefix/形式 の対応表。store layout / バケット一覧 / プレフィックス定義はそこを唯一の正本とし、ここでは再掲しない）。

## タスク管理ルール

| 目的 | ツール |
|------|-------|
| セッション内の作業追跡 | `TaskCreate` `TaskUpdate`（Claude Code 組み込み） |
| 永続的なプロジェクトタスク | 実効 tasks ファイル（定義は下記） |

**実効 tasks ファイルの定義**: SessionStart hook が注入する「進行中タスク」見出し下のパスを最優先で使う。hook 注入が無い環境（Claude Desktop / IDE 拡張など）では、現在の WS 実体 `workspaces/<author>/<topic>/tasks.md` を探し、無ければ legacy の `tasks/active.md` を使う。

**タスクファイルの優先順位:**
1. 既存の `tasks.md` `TODO.md` `ROADMAP.md` がある → それを使う
2. なし → 実効 tasks ファイルを作成（新 layout の `tasks.md` があればそれ、なければ `tasks/active.md`）

**非標準のタスクファイル**: hook は情報としてのみ提示する。ユーザーが明示的に 「移動して」 / "move it" と言った時のみ移動する。

### 全タスク完了時の自動アーカイブ

詳細: [`references/task-lifecycle.md`](references/task-lifecycle.md)

要旨: 実効 tasks ファイルの全タスクが完了（`- [ ]` が 0 件 + `- [x]` が 1 件以上）したのを hook が検知 → `YYYY-MM-DD_{phase}.md` として退避（新 layout = 同 WS の `tasks-old/`、legacy = `tasks/old/`; hook 通知のパスに従う; 名前は `## Phase:` ヘッダーから抽出）。既存の `tasks.md` / `TODO.md` 使用時はアーカイブしない。

## セットアップ / 移行 / denylist 管理

詳細: [`references/setup.md`](references/setup.md)

要旨:
- **fallback**: hook の無い環境（Claude Desktop / IDE 拡張 / Web UI）では `bash "${CLAUDE_PLUGIN_ROOT}/hooks/_ai-context-scaffold.sh" "$PWD"` で store skeleton（または仮ローカル）を冪等に生成する（repo 内 `.ai-context/` は作らない）
- **denylist**: `~/.claude/banto-ignore` に登録されたパスでは hook が早期 exit する。`/ai-context ignore add/list/remove` で管理する
- **移行**: 既存の repo 内 `.ai-context/` は scaffold が検知時に非破壊自動移行する。`/ai-context migrate` は今すぐ揃えたいときの明示実行手段

## 過去のコンテキスト検索

**検索は `search` skill が所有する**。ユーザーが 「前に決めた」「思い出して」 ("we decided this before", "remember...") のように言うと、その skill が自動発火する。`/search <query>` で明示的に呼ぶこともできる。Claude がクエリを 3 層に展開 → ランキングスクリプトが grep で候補を採点 → 上位を Read で検証（対象: `{base}/` 配下の decisions/docs + `config.json` の `extra_docs_dirs`）。

## 検索テキスト層の管理（索引 / full-combined.txt）

search ランキング（`store-query.sh`）は `{base}/decisions/` `{base}/docs/` を**直接走査する**（combined.txt は読まない — search-layer-redesign 分岐 1A）。書き込み直後から検索対象になり、手動操作は不要。

補完する 2 層:
- **FTS5 セクション索引**: `{base}/decisions/` `{base}/docs/` への書き込みを契機に hook（`ai-context-index-rebuild.sh`）がバックグラウンドで自動再生成する。
- **full-combined.txt**（会話履歴込みの deep パス専用層）: 書き込みには追従せず、SessionStart の日次スロットル + deep パス開始時のオンデマンド更新でのみ再生成する。

検索対象を追加するには `config.json` の `extra_docs_dirs` を直接編集する（次回の索引 / full-combined.txt 再生成から有効になる）。

## チェックポイント作成

**`save-checkpoint` skill（`/save-checkpoint` コマンド）** に従う — それが single source of truth。hook が 「チェックポイント作成」 を通知したら、同様にその skill の手順で実行する。

- チェックポイントファイル: `{base}/sessions/checkpoint-{YYYY-MM-DD}-{HHMM}.md`
- PreCompact hook が次セッションへ注入した後に自動削除するので、AI が削除する必要はない

## 引数なしで呼ばれた時のヘルプ

```
Usage: /ai-context <bootstrap|local|doctor|sort|next|phase-done|ignore|tasks|migrate|memo|knowledge>

Examples:
  /ai-context bootstrap
  /ai-context local
  /ai-context memo この会話の要点
  /ai-context knowledge list
  /ai-context tasks split --auto
```

ユーザーが日本語を話す場合は日本語で応答する（このヘルプテキストを含む）。
