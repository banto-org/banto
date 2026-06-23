# セットアップ・移行・撤去（init / migrate / prune / denylist）

<!-- merged from init.md -->
## /ai-context init — 初期化詳細

## 目的

このプロジェクトを中央 store に登録し、store 側に標準バケット構造を作成する（store-first）。
**repo 内には何も作らない**（`.ai-context/` も `.gitignore` 追記もなし）。

## 実行手順

1. プロジェクトルート確認: `pwd`（git work-tree root であること。非 git の新規プロジェクトは
   先に `git init` または `/init` で土台を作る）
2. scaffold を実行（store root 確保 + mapping 登録 + store 側 skeleton 生成。冪等）:

```bash
sh "$CLAUDE_PLUGIN_ROOT/hooks/_ai-context-scaffold.sh" "$PWD"
```

3. base を解決して確認:

```bash
BASE=$(sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD")
ls "$BASE"
```

4. `$BASE/tasks/active.md` が無ければ空の雛形を作成:

```markdown
## Active Tasks

## Phase: （未設定）

### タスク

- [ ] 最初のタスクをここに書く

## ルール

- タスク完了時: `- [ ]` → `- [x]` に更新
- Phase完了時: 該当Phase部分を tasks/old/YYYY-MM-DD_phase-name.md に退避
```

5. 完了レポート:

```
✓ ai-context 初期化完了（store-first）
  base: {BASE}
  作成: decisions/, docs/research/, docs/knowledges/drafts/, sessions/,
        tasks/old/, workspaces/
  tasks/active.md: {作成 / 既存}
  repo 側: 変更なし（knowledge は store へ、code は repo へ）

次にやること:
  /ai-context status   → 現在の状態を確認
  /ws new       → ワークスペースを作成
```

## grandfather（既存の repo 内 `.ai-context/` がある場合）

既存 legacy base はそのまま使われ続ける（scaffold は不干渉・store 登録もしない）。
中央 store へ移すなら `/ai-context migrate`（人間ゲート。移行後は repo がクリーンになる）。

<!-- merged from migrate.md -->
## migrate — プロジェクトの ai-context を中央 store へ移行

`<project>/.ai-context/` の資産を中央 store（`~/ai-context-store/<project>/`）へコピー移行する。
エンジンは `scripts/migrate-to-store.sh`（copy モード・dry-run 既定・元 `.ai-context/` は消さない）。

## 前提

- 中央 store root（`~/ai-context-store/`、marker `.ai-context-store`）は store-first scaffold が
  自動作成済みのはず。無ければ `mkdir -p ~/ai-context-store && touch ~/ai-context-store/.ai-context-store`
  （チームで git 同期するなら `scripts/ai-context-store-init.sh`）。
- `.mapping.json`（`~/ai-context-store/.mapping.json`、ローカル限定・gitignore）に対象 cwd → project を登録（手順 1）。

## `migrate [path]`（既定 path = cwd）

1. **mapping 登録**: project 名は derive で決定する（dirname 衝突時に決定論 suffix が付く）:
   `PROJ=$(basename "$(sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --derive <abs-path>)")`
   → `.mapping.json` の `.projects[<abs-path>] = {"project": $PROJ}`（未登録時のみ追加）。
2. **dry-run**: `sh "$CLAUDE_PLUGIN_ROOT/scripts/migrate-to-store.sh" <path>` で移行対象を確認。
3. **apply**: `... --apply <path>`（`.ai-context/` 配下の**全ファイル**を copy = decisions/docs/tasks/archive/audit/concept 等 + `WORKSPACE.md` / `config.json`。再生成物（`*-combined.txt`）・`.obsidian/`・`.git/`・`.DS_Store` は除外。既存はスキップ。v5.21.7+）。
4. **検索層**: hook が自動再生成（手動不要）。
5. **報告**: 移行ファイル数 / store path / 元 legacy は保持（撤去は `prune`）。

## `migrate --all`

`~/Documents/productCodes` 直下で `.ai-context/` を持つプロジェクトを列挙し、各々を `migrate` する。
**除外**: 既に移行済み / worktree（同一 repo の別チェックアウト）/ denylist 登録パス。

### スコープの扱い（client / NDA）
`--all` は他社案件・NDA 対象を含むプロジェクトの知識を共有 org store（`<your-org>/ai-context-store`）へ集約・push し得る。
この cross-client 一括移動は**安全分類器（deterministic hook）が block** する設計で、解除はユーザー自身の `!` 実行による。
client 案件の移行可否（オーナー承認）は**運用者が out-of-band で管理する前提**とし、**AI からは承認を再要求しない**（冗長な確認を出さない）。client 案件は legacy 据え置きが既定で安全。

## store への反映（push）

移行コピー後、store を commit + push して共有/他マシン同期する（任意・別ステップ）:

```
git -C ~/ai-context-store add -A
git -C ~/ai-context-store commit -m "feat: migrate <project> ai-context to central store"
git -C ~/ai-context-store push origin main   # store は marker により main 直 push 許可
```

検索用成果物（`*-combined.txt` 等）・`.mapping.json`・`[Memo]*` は store の `.gitignore` で除外済み。

<!-- merged from prune.md -->
## prune — 空 / 不要フォルダの検出と確認削除

ai-context まわりの「空ディレクトリ」「中央移行後の legacy」「非プロジェクト場所の誤生成」を検出し、
**一覧提示 → ユーザー確認 → 削除**する。削除は破壊操作なので**必ず確認**してから（自走原則: 提案は自動・破壊は確認）。

## 検出する 3 種

### A. 空ディレクトリ
ai-context ベース配下で中身が無い（`.gitkeep` のみ含む場合も候補）ディレクトリ。
```
BASE=$(sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD")
find "$BASE" -type d -empty 2>/dev/null
## .gitkeep だけのディレクトリも候補に含めるなら別途判定
```

### B. 中央移行後の in-repo legacy `.ai-context/`
central mode（`.mapping.json` 登録 or `config.json: mode=central`）が有効なプロジェクトで、
リポジトリ内に旧 `.ai-context/` が残っている場合。**store に同等の内容がある事を検証してから**撤去提案。
```
mode=$(...) ; [ "$mode" = central ] || skip
## store project dir に decisions/docs が存在することを確認
## 一致を確認できたら「in-repo legacy を撤去しますか？」と確認
```
- in-repo `.ai-context/` が **git 管理下**なら、削除はそのリポジトリの git 変更になる。削除後は当該 repo で
  ユーザーに commit を促す（勝手に commit しない）。

### C. 非プロジェクト場所の誤生成
`$HOME` 直下・git work tree 外などにできた `.ai-context/`（`_ai-context-scaffold.sh` の場所ガード以前の遺物）。
中身（実ファイル）があれば**移動先を確認**してから、空なら削除確認。

## 手順

1. 上記 A/B/C を走査し、**カテゴリ別に一覧表示**（パス + ファイル数 + git 管理下か）。
2. 各候補について削除/撤去の可否をユーザーに確認（まとめてでも 1 件ずつでも可）。実データを持つものは**中身を失わない**事を保証（B は store 検証済み、C は移動先確認済み）。
3. 確認できたものだけ `rm -rf`（`$HOME` / FS ルート等は対象外）。
4. 結果報告（削除数 / 保持したもの / git 変更が出た repo）。

## 禁止 / 安全

- 確認なしの削除はしない。
- 他プロジェクトの**実データを持つ** `.ai-context/`（移行未済）は削除しない。移行（`migrate`）が先。
- `$HOME` / `/` 等の破壊的削除は odd-kill-switch と二重で防がれる。

<!-- merged from setup-and-denylist.md -->
## 初回セットアップと denylist 管理

## 初回セットアップ（hook 動かない環境向け fallback）

CLI 環境では hook (`ai-context-auto.sh` / `ai-context-session-start.sh`) が中央 store 側に skeleton を自動生成する（store-first: repo 内には何も作らない）。**Claude Desktop / IDE 拡張 / Web UI では hook が発火しない**ため、このスキル発火時に base 未生成を検知したら以下を Bash で実行して fallback する:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/hooks/_ai-context-scaffold.sh" "$PWD"
```

`_ai-context-scaffold.sh` は **store 側のみ**に書き込む（store root 確保 + mapping 登録 + project skeleton 生成）。repo の `.gitignore` には一切触れない。生成される標準バケットは [`directory-structure.md`](directory-structure.md) の store layout を参照。

**確認手順**: スキル発火直後に `BASE=$(sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD")` で base を解決し、`[ -d "$BASE/decisions" ]` を確認、なければ上記コマンドを実行。既存時は何もしない（idempotent）。

## Denylist 管理（banto 自体の除外）

特定のプロジェクトでは hook を**動かしたくない**ケース（試作・他人のリポジトリ・一時作業ディレクトリ等）に対応するため、`~/.claude/banto-ignore` に列挙されたパス（および配下）では SessionStart / UserPromptSubmit hook が早期 exit する。

ユーザーが「このプロジェクトで ai-context 動かさないで」「scaffold 抑止」「除外したい」のような発言をしたら、コマンド経由で登録する:

```
/ai-context ignore add            # 現在の CWD を除外
/ai-context ignore add <path>     # 任意パスを除外
/ai-context ignore list           # 登録一覧
/ai-context ignore remove <N>     # 行番号 N を削除
```

ファイル仕様は `references/ignore.md` 参照。

注意: denylist 追加は**そのパス（および配下）での新規 store scaffold をプロジェクト単位で抑止するだけ**。既に store 側に作られた project dir はユーザーが手動で削除する必要がある（破壊的操作のため自動化しない）。repo 側には元々何も作られないため、repo の掃除は不要。

## 自動 scaffold の発火条件（場所ガード）

denylist とは別に、`_ai_context_should_skip` が **非プロジェクト場所への誤生成を deterministic に防ぐ**:

- **git work tree 内でのみ**自動 scaffold する。`$HOME` 直下・ファイルシステムルート・git 管理外ディレクトリでは store project dir を作らない（HOME からセッションを開いても store に誤った project が登録されない）。
- 非 git の新規プロジェクトは `/init` + `harness-setup.sh --project` で明示的に scaffold する（自走ハーネス原則: 明示の意図がある時だけ作る）。
- このガードは denylist ファイルの有無に依存しない（ファイルが無くても常時有効）。

