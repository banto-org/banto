# 移行・fallback セットアップ・denylist（migrate / denylist）

> 初回セットアップ（旧 `init`）は `bootstrap` に統合した（SKILL.md「store ブートストラップ」）。
> 空 / 移行済み legacy / 誤生成フォルダの掃除（旧 `prune`）は hook で自動化した（手動サブコマンドは廃止。
> 手動の掃除が要れば `doctor` の報告に従う）。本ファイルは **移行（`migrate`）** と **fallback セットアップ + denylist** を扱う。

<!-- merged from migrate.md -->
## migrate — プロジェクトの ai-context を中央 store へ移行

repo 内の既存 `.ai-context/`（legacy 案件）の資産を中央 store（`~/ai-context-store/<project>/`）へコピー移行する。
エンジンは `scripts/migrate-to-store.sh`（copy モード・dry-run 既定・元 `.ai-context/` は消さない）。

> 注意: ここでの `.ai-context/` は **legacy repo の repo 内ディレクトリ**を指す（移行元）。
> 移行先の base は store 側の絶対パス。store-first では新規生成は base（store）側のみで、相対 `.ai-context/` には書かない。

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
3. **apply**: `... --apply <path>`（repo 内 `.ai-context/` 配下の**全ファイル**を copy = decisions/docs/tasks/archive/audit/concept 等 + `WORKSPACE.md` / `config.json`。再生成物（`*-combined.txt`）・`.obsidian/`・`.git/`・`.DS_Store` は除外。既存はスキップ。v5.21.7+）。
4. **検索層**: hook が自動再生成（手動不要）。
5. **報告**: 移行ファイル数 / store path / 元 legacy は保持（撤去は hook が自動化）。

## `migrate --all`

`~/Documents/productCodes` 直下で repo 内 `.ai-context/` を持つプロジェクトを列挙し、各々を `migrate` する。
**除外**: 既に移行済み / worktree（同一 repo の別チェックアウト）/ denylist 登録パス。

### スコープの扱い（client / NDA）
`--all` は他社案件・NDA 対象を含むプロジェクトの知識を共有 org store（`<your-org>/ai-context-store`）へ集約・push し得る。
この cross-client 一括移動は**安全分類器（deterministic hook）が block** する設計で、解除はユーザー自身の `!` 実行による。
client 案件の移行可否（オーナー承認）は**運用者が out-of-band で管理する前提**とし、**AI からは承認を再要求しない**（冗長な確認を出さない）。client 案件は legacy 据え置きが既定で安全。

## store への反映（push）

移行コピー後、store を commit + push して共有 / 他マシン同期する（任意・別ステップ）:

```
git -C ~/ai-context-store add -A
git -C ~/ai-context-store commit -m "feat: migrate <project> ai-context to central store"
git -C ~/ai-context-store push origin main   # store は marker により main 直 push 許可
```

検索用成果物（`*-combined.txt` 等）・`.mapping.json`・`[Memo]*` は store の `.gitignore` で除外済み（区分の正本は [`directory-structure.md`](directory-structure.md)）。

<!-- merged from setup-and-denylist.md -->
## fallback セットアップと denylist 管理

## fallback セットアップ（hook 動かない環境向け）

CLI 環境では hook (`ai-context-auto.sh` / `ai-context-session-start.sh` / `_ai-context-scaffold.sh`) が中央 store 側（または未登録時は仮ローカル `~/ai-context-local/<project>/`）に skeleton を自動生成する（store-first: repo 内 `.ai-context/` は作らない）。**Claude Desktop / IDE 拡張 / Web UI では hook が発火しない**ため、このスキル発火時に base 未生成を検知したら以下を Bash で実行して fallback する:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/hooks/_ai-context-scaffold.sh" "$PWD"
```

`_ai-context-scaffold.sh` は **store / 仮ローカル側のみ**に書き込む（store root 確保 + mapping 登録 + project skeleton 生成）。repo の `.gitignore` には一切触れない。生成される標準バケットは [`directory-structure.md`](directory-structure.md) の store layout を参照（ここでは再掲しない）。

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

注意: denylist 追加は**そのパス（および配下）での新規 store scaffold をプロジェクト単位で抑止するだけ**。既に store / 仮ローカル側に作られた project dir はユーザーが手動で削除する必要がある（破壊的操作のため自動化しない）。repo 側には元々何も作られないため、repo の掃除は不要。

## 自動 scaffold の発火条件（場所ガード）

denylist とは別に、`_ai_context_should_skip` が **非プロジェクト場所への誤生成を deterministic に防ぐ**:

- **git work tree 内でのみ**自動 scaffold する。`$HOME` 直下・ファイルシステムルート・git 管理外ディレクトリでは store / 仮ローカル project dir を作らない（HOME からセッションを開いても誤った project が登録されない）。
- 非 git の新規プロジェクトは `/init` + `harness-setup.sh --project` で明示的に scaffold する（自走ハーネス原則: 明示の意図がある時だけ作る）。
- このガードは denylist ファイルの有無に依存しない（ファイルが無くても常時有効）。
