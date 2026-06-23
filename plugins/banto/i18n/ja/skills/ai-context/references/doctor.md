# /ai-context doctor — 診断詳細

## 目的
`.ai-context/` の構成異常**＋プロジェクト全体の健康状態**を検出して報告するのみ。修正は行わない（sort または案内に誘導）。

> store-first: BASE 解決は SKILL.md 冒頭のとおり。診断対象の `.ai-context/` は解決した `$BASE/` に読み替える。

## 診断項目（.ai-context/ 範囲）

**A. 欠損ディレクトリ**
期待パスのうち存在しないものを列挙:
`decisions/`, `docs/research/`, `docs/knowledges/drafts/`, `sessions/`, `tasks/old/`, `workspaces/`

**B. 誤配置の疑い**

1. `.ai-context/` 直下に想定外のディレクトリ
2. `docs/` 直下で `research/` `knowledges/` 以外のディレクトリに `[Prefix]` 付きファイルが無い / プレフィックス違反
3. `decisions/` 内でファイル名が `YYYY-MM-DD*.md` パターン（タイムスタンプ/旧NNN 両形式）に合わないファイル
4. `sessions/` 内に古い（30日以上前）チェックポイント
5. `docs/` 直下で以下のプレフィックスを持たないファイル（README.md は例外):
   `[Review]` `[QA]` `[Audit]` `[Status]` `[Design]` `[Guide]` `[Memo]` `[Index]`
6. `decisions/` に空ファイル（<100 bytes）

**C. .gitignore 不整合**
`.ai-context/sessions/` `.ai-context/project-index/` 等が未登録

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

**I. リンター/フォーマッター**
- `biome.json` / `.eslintrc*` / `.prettierrc*` / `ruff.toml` 存在確認
- なければ → 推奨案内

**J. tasks/active.md の健全性**
- 行数 > 200 → 「分割推奨」
- `## Phase:` ヘッダー数 ≥ 4 → 「複数 Phase 混在、整理推奨」

## 出力フォーマット

```
## 診断結果

### .ai-context/ 範囲
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
| J. active.md | ✓/⚠ | 行数 / Phase 数 |

### 提案
- 修正が必要: `/ai-context sort` で対話的に振り分け
- プロジェクト側の不足: `harness-setup.sh --project` で生成
- 問題なし: ✓ 健全
```

**書き込みは一切しない**。ユーザーが修正したい場合は `/ai-context sort` へ誘導。
