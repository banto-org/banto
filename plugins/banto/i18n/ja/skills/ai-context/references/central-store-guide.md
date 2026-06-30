# 中央 store — デプロイ / 同期 / チーム運用ガイド（store-first）

ai-context の知識（decisions / docs / tasks / sessions / workspaces）は**中央 store**
（既定 `~/ai-context-store/<project>/`）に集約される。**store-first（v5.30.0+）ではセットアップ不要で
最初からここに書かれる** — 任意なのは「チームで git 同期するか」だけ。

## 解決順（hook がどこを base にするか）

1. **mapping hit**: `<store>/.mapping.json` に登録済み → その project dir
2. **grandfather**: repo 内に既存 `.ai-context/` が実在する legacy repo のみ → repo 内のまま動作
   （`/ai-context migrate` で store へ移行可能）
3. **derive**: 未登録なら `<store>/<git toplevel の dirname>/` を自動採番（衝突時 `-2` suffix）+ 自動登録

repo 側には何も作られない（CONTRACT.md「footprint 例外ゼロ」）。

---

## シナリオ別手順

### (a) 個人 1 台で使い始める — **やることなし**

plugin を入れて repo で Claude Code を起動するだけ。初回セッションの scaffold が
store root（marker `.ai-context-store` + `.mapping.json`）と project skeleton を自動作成し、
以降の decisions / tasks はそこに着地する。`harness-setup.sh` を済ませていれば確実。

- store root の場所を変えたい: settings.json の `env.AI_CONTEXT_STORE_ROOT` で上書き
- 確認コマンド: `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`

### (b) 2 台目の PC に持っていく（個人マルチマシン）

知識の実体は `~/ai-context-store/` 一式。これを移すだけでよい。**3 手順**:

1. 新端末に banto を install（`claude plugin install banto@banto-marketplace` + `harness-setup.sh`）
2. store を持ち込む — どちらか:
   - **git 同期している場合（(d) の solo バックアップ済み / チーム (c)）**: `git clone <自分の store repo> ~/ai-context-store`
   - git にしていない場合: `rsync -a 旧:~/ai-context-store/ ~/ai-context-store/`
3. 各 project repo を任意の場所に clone して Claude Code を起動するだけ:
   - git remote がある repo → `.mapping-template.json`（remotes ベース）or derive（同 dirname）で自動再接続
   - **端末固有のパス登録は不要**（resolver の remote フォールバック、v5.21.22+）

`.mapping.json` 自体は端末ローカル（store 用 .gitignore で除外）。持ち込まなくても自動再生成される。

**複数台を git で並走させる場合の運用ルール**: セッション開始前に `git -C ~/ai-context-store pull --rebase`
（push は PreCompact auto-sync / nightly が片道自動。pull は現状手動 — 取り込み忘れが古い知識での作業になる）。

### (c) チームで git 同期する

store を private git repo にするだけ。**store は内部名・案件横断知識を含むため private 必須**。

初回（管理者・1 回だけ）:
```sh
cd ~/ai-context-store
git init -b main && git add -A && git commit -m "init store"
gh repo create <org>/ai-context-store --private --source . --push   # private 必須
```
メンバー（各端末で 1 回）: org を **`~/.claude/banto-store-target.conf`** に設定して
（`AI_CONTEXT_STORE_ORG="<org>"` の 1 行。plugin 内 `config/store-target.conf` の編集でも動くが
**`claude plugin update` のたびに巻き戻る**ため user-scope 側を推奨）
`sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-context-store-init.sh"`
（= clone + `.mapping.json` を `.mapping-template.json` から自動生成）。

日々の同期（push はチーム/他マシン同期用。しなくてもローカルでは全機能が動く）:
```sh
git -C ~/ai-context-store pull --rebase
git -C ~/ai-context-store add -A && git -C ~/ai-context-store commit -m "..."
git -C ~/ai-context-store push origin main   # store は marker で main 直 push 許可（コード repo と逆ポリシー）
```

### (d) バックアップ / リストア

- **バックアップ対象は `~/ai-context-store/` 一式のみ**（repo 側に知識は無い）

**solo の git バックアップ（推奨・1 回だけ）** — store-first の初期状態は git repo ではないので、まず init する:

```sh
git -C ~/ai-context-store init -b main
git -C ~/ai-context-store add -A && git -C ~/ai-context-store commit -m "init store"
gh repo create <あなたのアカウント>/ai-context-store --private --source ~/ai-context-store --push   # private 必須
```

以後は PreCompact auto-sync / nightly push が効く（store は marker により main 直 push 許可）。
git にしない運用なら Time Machine / rsync 等でディレクトリごと保全する。

- 再生成可能物はバックアップ不要: `combined.txt`（検索テキスト層・hook が自動再生成）
- リストア = (b) と同じ（ディレクトリを戻して起動するだけ）

---

## legacy repo の移行と撤去

- **repo 内 `.ai-context/` → store**: 対象 repo で `/ai-context migrate`
  （= `--derive` で mapping 登録 → `migrate-to-store.sh --apply` → combined 再生成。詳細は `references/setup.md`）。
  移行は **copy**（元は残る）。一括は `/ai-context migrate --all`
- **撤去**: 移行済み legacy / 誤生成フォルダの掃除は hook が自動化（旧 `/ai-context prune` は廃止。手動が要れば `/ai-context doctor` の報告に従う）。
  前提: store が push 済み（バックアップ）であること
- store 内の旧 layout → 新 layout（workspace 束ね）: `sh "$CLAUDE_PLUGIN_ROOT/scripts/migrate-store-layout.sh" --all` → `--apply`

## 日常の使い方（参照・保存）

- SessionStart hook が `[AI Context - 中央 store 運用] ... ベース: <絶対パス>` を注入 →
  decisions / docs / tasks は常に**注入された絶対パス配下**を Read/Write
- 検索は `/search <query>`（store の decisions/docs が対象）。検索対象の追加は `config.json` の `extra_docs_dirs`
- plugin 更新・mapping 変更は **Claude Code 再起動**で反映

## 関連

- `references/setup.md`（移行 migrate / fallback / denylist）/ `references/directory-structure.md`（外部ツール向け read 契約）
- `~/ai-context-store/README.md`（store レイアウト）
