# /ai-context doctor — 診断詳細（status 統合 + health lint）

## 目的
`{base}/` の構成異常 **＋ store の健全性（health lint）＋ プロジェクト全体の健康状態** を検出し、**状態表示（旧 status）も兼ねて**報告するのみ。修正は行わない（sort または案内に誘導）。

> store-first: BASE 解決は SKILL.md 冒頭のとおり。診断対象の `{base}/` は解決した base 配下を指す。バケット名・プレフィックス定義の正本は [`directory-structure.md`](directory-structure.md)。

> **status 統合（0.1.4〜）**: 旧 `/ai-context status`（何があるかの読み取り表示）は doctor へ統合した。診断の前段で件数サマリ（下記「状態サマリ」）を出し、続けて診断項目を報告する。`status` で呼ばれても doctor として実行する（後方互換エイリアス・警告 1 行）。

## 状態サマリ（旧 status・読み取りのみ）

Glob と `wc -l` 等で各種カウントを取得し、何が格納されているかを表示する（base 配下のみ読む。書き込みなし）:

```bash
BASE=$(sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD")
find "$BASE/decisions" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l
find "$BASE/decisions" -maxdepth 1 -name "$(date +%Y-%m-%d)*.md" 2>/dev/null | wc -l
find "$BASE/docs/research" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l
find "$BASE/docs/knowledges/drafts" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l
find "$BASE/sessions" -type f -name "*.md" 2>/dev/null | wc -l
```

実効 tasks ファイル（SessionStart の「進行中タスク」見出しのパス。新 layout = `workspaces/<author>/<topic>/tasks.md`、legacy = `tasks/active.md`）があれば未完 / 完了件数と Phase 名を表示する。

出力例:
```
### 状態サマリ（base: {BASE}）
| 領域 | 件数 | 備考 |
|---|---|---|
| decisions/ | N件 (本日: M件) | 最新: YYYY-MM-DD-HHMMSS_... |
| docs/research/ | N件 | 最新: ... |
| docs/knowledges/drafts/ | N件 | 昇格は `/ai-context knowledge` |
| sessions/ | N件 | （一時的） |
| 実効 tasks | 未完 X / 完了 Y | Phase: ... |
```

## store health lint（リンク切れ / 孤立 / 矛盾候補 / 陳腐化）

decisions/ のリンク切れ・孤立・矛盾候補・陳腐化を**検出のみ**する health lint を呼ぶ（修正はしない。WT-C 提供）:

```bash
sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-context-lint.sh" "$PWD" 2>/dev/null || echo "(lint 未提供 / jq 不在 → スキップ)"
```

lint の出力をそのまま「health」セクションとして報告する。lint スクリプトが無い・jq 不在の環境では fail-open でスキップし、診断の他項目は続行する。

> **interface（WT-C）**: `scripts/ai-context-lint.sh [cwd]` は cwd（省略時 $PWD）から base を解決し、decisions/ の高確度な不健全（リンク切れ / 孤立 / 矛盾候補 / 陳腐化）を**検出して列挙するのみ**で、自動修正はしない。

## 診断項目（base 範囲）

**A. 欠損ディレクトリ**
期待バケットのうち存在しないものを列挙（バケット一覧の正本は [`directory-structure.md`](directory-structure.md)）。

**B. 誤配置の疑い**

1. base 直下に想定外のディレクトリ
2. `docs/` 直下で `research/` `knowledges/` 以外のディレクトリに `[Prefix]` 付きファイルが無い / プレフィックス違反
3. `decisions/` 内でファイル名が `YYYY-MM-DD*.md` パターン（タイムスタンプ / 旧 NNN 両形式）に合わないファイル
4. `sessions/` 内に古い（30 日以上前）チェックポイント
5. `docs/` 直下で固定プレフィックス（[`directory-structure.md`](directory-structure.md) 参照）を持たないファイル（README.md は例外）
6. `decisions/` に空ファイル（<100 bytes）

**C. .gitignore 不整合**
store 側 `.gitignore`（`sessions/` / `*-combined.txt` 等）の区分が崩れていないか（区分の正本は [`directory-structure.md`](directory-structure.md)）。

**D. hooks 登録**
`.claude/settings.json` に ai-context 系 hook が登録されていない（プロジェクトレベル）場合は情報提示。

## 診断項目（プロジェクト全体）

**E. Git 状態**
```bash
git status --porcelain 2>/dev/null | wc -l
git branch --show-current 2>/dev/null
```
- 未コミット変更が 20 件以上 → 警告
- main/master ブランチで直接作業 → 警告

**F. CLAUDE.md**
- プロジェクトルートに `CLAUDE.md` または `.claude/CLAUDE.md` があるか
- なければ → 「ネイティブ `/init` で生成できます」と案内

**G. .claude/rules/**
- ディレクトリと中の md ファイルの存在確認
- なければ → 「`harness-setup.sh --project` でルールを生成できます」と案内

**H. テスト設定**
- `package.json` の `test` スクリプト / `pyproject.toml` / `Cargo.toml` / `go.mod` 存在確認
- なければ → 警告

**I. リンター / フォーマッター**
- `biome.json` / `.eslintrc*` / `.prettierrc*` / `ruff.toml` 存在確認
- なければ → 推奨案内

**J. 実効 tasks ファイルの健全性**
- 行数 > 200 → 「分割推奨」（`/ai-context tasks split`）
- `## Phase:` ヘッダー数 ≥ 4 → 「複数 Phase 混在、整理推奨」

## 出力フォーマット

```
## 診断結果

### 状態サマリ（base: {BASE}）
（上記「状態サマリ」テーブル）

### health（store lint）
（ai-context-lint.sh の出力 / または「lint スキップ」）

### base 範囲
#### A. 欠損ディレクトリ
✓ / ⚠ 一覧

#### B. 誤配置の疑い
| # | パス | 種類 | 推奨アクション |
|---|------|------|---------------|
| 1 | docs/note.md | プレフィックス無し | `/ai-context sort` |

#### C. .gitignore
- {OK / 追記推奨}

#### D. hooks 登録
- {OK / 登録不足}

### プロジェクト全体
| 項目 | 状態 | 詳細 |
|------|------|------|
| E. Git | ✓/⚠ | ブランチ名・未コミット件数 |
| F. CLAUDE.md | ✓/⚠ | パス or 欠損 |
| G. .claude/rules/ | ✓/⚠ | md ファイル数 |
| H. テスト設定 | ✓/⚠ | package.json / pyproject / Cargo など |
| I. リンター | ✓/⚠ | biome / eslint / prettier / ruff |
| J. 実効 tasks | ✓/⚠ | 行数 / Phase 数 |

### 提案
- 誤配置の修正: `/ai-context sort` で対話的に振り分け
- ドラフトの整理: `/ai-context knowledge` で昇格 / 削除
- プロジェクト側の不足: `harness-setup.sh --project` で生成
- 問題なし: ✓ 健全
```

**書き込みは一切しない**。ユーザーが修正したい場合は `/ai-context sort`（誤配置）/ `/ai-context knowledge`（ドラフト）へ誘導。
