---
name: ai-context
description: |
  AI コンテキスト管理: 決定ログ / チェックポイント / タスクファイル（tasks.md）編集 + 次タスクナビ + Phase 完了 / ドキュメント振り分け / scaffold 抑止管理。内部検索は `search` skill が所有する。
  トリガー: 「決定」「設計判断」「保存」「チェックポイント」「compact」「clear」「タスク」「TODO」「Phase」「続き」「次のタスク」「続きやって」「ドキュメント整理」「散らかってる」「除外」「動かさないで」「無効化」
  使わない場面: 既に格納済みのコンテキスト検索（`search` skill を使う）や外部ソースの調査（`research` を使う）。実装中の素の「やって」「進めて」は自走（直接動く）を意味し、タスク修飾付きのフレーズ（「次のタスク」「続きやって」）のみが次タスクナビへルーティングされる。スコープ用に git worktree / ブランチを切り替えるのは `ws` であって本 skill ではない。
allowed-tools: Read Write Edit Glob Grep Bash Agent
argument-hint: "[bootstrap|init|status|doctor|sort|next|phase-done|ignore|tasks|migrate|prune]"
compatibility: Claude Code (requires bash, git, jq)
---

# AI Context

> **格納ベースについて（store-first）**: この skill 中の `.ai-context/...` パスはすべて **ai-context ベースディレクトリ** —
> SessionStart / PreCompact hook が 「ai-context ベース: &lt;絶対パス&gt;」 として注入する絶対パス — を指す。常に
> **その注入された絶対パス配下**を Read/Write し、相対の `.ai-context/` には絶対に書き込まない（repo 内 `.ai-context/` は
> grandfather された legacy repo にのみ存在し、`/ai-context migrate` で移行するまでベースとして動き続ける）。
> ベースが不明なら 1 行で解決する: `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`。

> **出力言語**: 生成する成果物（決定ログ / tasks.md / チェックポイント / ステータス報告 など）はユーザーの会話言語で書く。`references/` の日本語テンプレートは構造的な雛形にすぎない — 見出し/ラベルは会話言語に合わせて翻訳する。

## サブコマンドルーター（明示的なユーザー呼び出し）

`$ARGUMENTS` の最初のトークンをサブコマンドとして解釈し、対応する references/ ファイルを Read してその手順に従う。

| サブコマンド | 役割 | 詳細 |
|---|---|---|
| `bootstrap` | store 未セットアップ時の対話セットアップ（既存登録／新規作成／ローカルのみ） | 下記「store ブートストラップ」 |
| `init` | ゼロから作成（初回セットアップ） | `references/setup.md` |
| `status` | 何があるか表示（書き込みなし） | `references/status.md` |
| `doctor` | 破損 / 誤配置の検出（書き込みなし） | `references/doctor.md` |
| `sort` | `.ai-context/` 内の誤配置ファイルを対話的に振り分け（書き込みあり） | `references/sort.md` |
| `sort project` | プロジェクト全体の散在ドキュメントを整理 | `references/sort.md` |
| `next` | 次の未完了タスクを特定し実装まで完遂 | `references/task-lifecycle.md` |
| `phase-done [N]` | Phase 完了チェック + 検証 + アーカイブ | `references/task-lifecycle.md` |
| `ignore` | scaffold 抑止パスを管理（書き込みあり） | `references/ignore.md` |
| `tasks split` | tasks.md を Phase 単位で分割 | `references/task-lifecycle.md` |
| `migrate [path\|--all]` | プロジェクトの ai-context を中央 store へ移行 | `references/setup.md` |
| `prune` | 空 / 移行済み legacy / 誤生成フォルダを検出して確認削除 | `references/setup.md` |

引数が空または不明な場合は使い方を表示する。

**自然言語からの発火**: 明示サブコマンドに加えて、文脈から自動ルーティングする: 「続き」「次」「次のタスク」「進めて」 / "continue", "next", "next task", "go ahead" → `next`; 「ドキュメント整理」「散らかってる」 / "organize the docs", "it's a mess" → `sort project`; 「Phase 完了」 / "phase done" → `phase-done`; SessionStart hook が「store 未セットアップ」案内を出した時・「store を作って」「ai-context-store をセットアップ」 → `bootstrap`。

**中央 store 運用（チーム / 複数プロジェクト）**: repo 内 `.ai-context/` から `~/ai-context-store/<project>/` へ ai-context を集約する end-to-end 手順（セットアップ → 移行 `migrate` → 参照 → push → 撤去 `prune`）は [`references/central-store-guide.md`](references/central-store-guide.md) にある。

## store ブートストラップ（`bootstrap`）

SessionStart hook はこの repo が中央 ai-context-store に未登録のとき「store 未セットアップ」案内を 1 回だけ出す（黙ってローカル store を作らない）。hook は会話できないため、実際のセットアップ対話はここで進める。**3 択を 1 つの会話**で確認する（モーダルは使わず、普通の文章でひとつずつ聞く）:

1. **既に GitHub に ai-context-store がある場合**: repo を `org/name` で確認 → 既存登録モードで取り込む（作成しない）:
   ```bash
   sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-context-store-init.sh" --register <org>/<name>
   ```
   clone + mapping 登録のみ実行し、org を `~/.claude/banto-store-target.conf` に保存する。
2. **無ければ新規作成する場合**: どの org（または GitHub ユーザー名）に置くか確認 → private 固定で作成:
   ```bash
   sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-context-store-init.sh" --create <org>
   ```
   `gh repo create --private` で作成し、選んだ org を `~/.claude/banto-store-target.conf` に保存する。2 回目以降のプロジェクトは org が保存済みのため、作成の可否だけ確認すればよい（org は再入力不要）。
3. **ローカルのみで使う場合（GitHub を使わない退避）**: store ルートと mapping だけローカルに用意し、この repo を登録する。**明示オプトインの env で実行**する（既定では黙って作らないため）:
   ```bash
   BANTO_BOOTSTRAP_LOCAL=1 sh "$CLAUDE_PLUGIN_ROOT/hooks/_ai-context-scaffold.sh" "$PWD"
   ```
   登録後は次回 SessionStart から store ベースが注入される（marker `~/.claude/banto-bootstrap-asked/<slug>` により `bootstrap` 案内は 2 回目以降出ない）。

いずれの分岐でも、登録が済めば次回 SessionStart から「ai-context ベース: &lt;絶対パス&gt;」が注入され、decisions / docs / tasks を store 側へ書けるようになる。org を保存だけしたい時は `--org <org>`、既存の repo 内 `.ai-context/` を store へ移すなら `bootstrap` ではなく `migrate`（読み取り互換は維持されるため急がなくてよい）。

## 決定の保存（自動保存 / 形式 / シークレット）

詳細: [`references/decisions.md`](references/decisions.md)

- **いつ**: 設計判断が発生した瞬間（コミットを待たない）。保存する＝設計方針 / 技術選定 / アーキ変更 / トレードオフ / 根本原因。保存しない＝単純実装 / typo / 事実回答のみ。
- **どこ**: `.ai-context/decisions/YYYY-MM-DD-HHMMSS_{topic-slug}_{github-account}.md`（PreToolUse hook が推奨名を注入; 旧 `YYYY-MM-DD_NNN_` 形式も有効）。
- **形式**: 軽量（タイトル + 判断）/ 完全（出発点 / 選択肢 / 決め手 / 不採用理由 / **フリクション** / **学んだこと**）。フリクションと学びが組織学習の核。
- **シークレット**（鉄則）: `sk-*` / `ghp_*` / `Bearer *` / `.env` 値を decisions / チェックポイントに書かない → `{SECRET}` に置換。露出時は即 **revoke / rotation**（チャット履歴に残る）。

## ディレクトリ構造 / プレフィックス

詳細: [`references/directory-structure.md`](references/directory-structure.md)

主要バケット:
- `decisions/` 設計判断ログ / `docs/` 報告系ドキュメント（プレフィックス必須）/ `workspaces/<author>/<topic>/tasks.md`（新 layout; legacy は `tasks/active.md`）/ `sessions/`
- `docs/` 直下のプレフィックス: `[Review]` `[QA]` `[Audit]` `[Status]` `[Design]` `[Guide]` `[Memo]` `[Index]`（hook で強制; 新しいプレフィックスを勝手に作らない）

## タスク管理ルール

| 目的 | ツール |
|------|-------|
| セッション内の作業追跡 | `TaskCreate` `TaskUpdate`（Claude Code 組み込み） |
| 永続的なプロジェクトタスク | 実効 tasks ファイル（SessionStart の「進行中タスク」見出し下のパス; 新 layout = `workspaces/<author>/<topic>/tasks.md`、legacy = `tasks/active.md`） |

**タスクファイルの優先順位:**
1. 既存の `tasks.md` `TODO.md` `ROADMAP.md` がある → それを使う
2. なし → 実効 tasks ファイルを作成（新 layout の `tasks.md` があればそれ、なければ `tasks/active.md`）

**非標準のタスクファイル**: hook は情報としてのみ提示する。ユーザーが明示的に 「移動して」 / "move it" と言った時のみ移動する。

### 全タスク完了時の自動アーカイブ

詳細: [`references/task-lifecycle.md`](references/task-lifecycle.md)

要旨: 実効 tasks ファイルの全タスクが完了（`- [ ]` が 0 件 + `- [x]` が 1 件以上）したのを hook が検知 → `YYYY-MM-DD_{phase}.md` として退避（新 layout = 同 WS の `tasks-old/`、legacy = `tasks/old/`; hook 通知のパスに従う; 名前は `## Phase:` ヘッダーから抽出）。既存の `tasks.md` / `TODO.md` 使用時はアーカイブしない。

## 初回セットアップ / denylist 管理

詳細: [`references/setup.md`](references/setup.md)

要旨:
- **fallback**: hook の無い環境（Claude Desktop / IDE 拡張 / Web UI）では `bash "${CLAUDE_PLUGIN_ROOT}/hooks/_ai-context-scaffold.sh"` で `.ai-context/` を冪等に生成する
- **denylist**: `~/.claude/banto-ignore` に登録されたパスでは hook が早期 exit する。`/ai-context ignore add/list/remove` で管理する

## 過去のコンテキスト検索

**検索は `search` skill が所有する**。ユーザーが 「前に決めた」「思い出して」 ("we decided this before", "remember...") のように言うと、その skill が自動発火する。`/search <query>` で明示的に呼ぶこともできる。Claude がクエリを 3 層に展開 → ランキングスクリプトが grep で候補を採点 → 上位を Read で検証（対象: `.ai-context/` 配下の decisions/docs + `config.json` の `extra_docs_dirs`）。

## 検索テキスト層の管理（combined.txt）

検索の grep 対象である `combined.txt` は **保存時に hook（`ai-context-combined-rebuild.sh`）が自動再生成する**:
- `.ai-context/decisions/` への書き込み時
- `.ai-context/docs/` への書き込み時
- バックグラウンドで動作（デバウンス）

手動操作は不要。検索対象を追加するには `config.json` の `extra_docs_dirs` を直接編集する; 次回の hook 再生成から有効になる。

## チェックポイント作成

**`save-checkpoint` skill（`/save-checkpoint` コマンド）** に従う — それが single source of truth。hook が 「チェックポイント作成」 を通知したら、同様にその skill の手順で実行する。

- チェックポイントファイル: `.ai-context/sessions/checkpoint-{YYYY-MM-DD}-{HHMM}.md`
- PreCompact hook が次セッションへ注入した後に自動削除するので、AI が削除する必要はない

## 引数なしで呼ばれた時のヘルプ

```
Usage: /ai-context <bootstrap|init|status|doctor|sort|next|phase-done|ignore|tasks|migrate|prune>

Examples:
  /ai-context bootstrap
  /ai-context init
  /ai-context tasks split --auto
```

ユーザーが日本語を話す場合は日本語で応答する（このヘルプテキストを含む）。
