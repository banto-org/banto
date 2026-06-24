# /ai-context sort — 振り分け詳細（内部 + プロジェクト全体、旧 doc-sort 統合）

2 モードを引数で切替:

| 呼び出し | モード | 対象 |
|---|---|---|
| `/ai-context sort` | **内部モード**（既定） | `{base}/` 内の誤配置振り分け |
| `/ai-context sort project` | **プロジェクト全体モード**（旧 doc-sort） | ルート直置き / `docs/` 等の散在ドキュメント整理 |

「ドキュメント整理」「散らかってる」「docs 移動」等の自然言語でも ai-context が発火し、文脈からモードを判断する（プロジェクト全体っぽければ project モード）。

---

## 内部モード（既定）

### 目的
`{base}/` 内の誤配置を**対話形式で振り分け**する（doctor で検出したもの）。ユーザー承認なしに移動しない。

> store-first: BASE 解決は SKILL.md 冒頭のとおり。以下の `{base}/` は解決した base 配下を指す。バケット名・プレフィックス定義の正本は [`directory-structure.md`](directory-structure.md)。

### 実行手順

1. 内部的に doctor の診断を再実行（書き込みなし）
2. 移動候補を分類して提示:

```
## {base}/ 振り分け候補

### [プレフィックス違反] docs/ 直下
| # | ファイル | 推奨アクション | 理由 |
|---|---------|--------------|------|
| 1 | docs/meeting-notes.md | `[Memo] meeting-notes.md` にリネーム | 議事録系 |
| 2 | docs/api-review.md | `[Review] api-review.md` にリネーム | レビュー系 |

### [日付欠落] decisions/
| # | ファイル | 推奨アクション |
|---|---------|--------------|
| 4 | decisions/old-decision.md | YYYY-MM-DD_old-decision_<user>.md にリネーム |

### [古いセッション] sessions/
| # | ファイル | 更新日 | 推奨アクション |
|---|---------|--------|--------------|
| 5 | checkpoint-2026-03-01-1430.md | 46日前 | 削除 |
```

3. ユーザーに選択を仰ぐ:

```
番号で指定してください:
- 全て実行 → "all"
- 個別に確認 → "each"
- 番号指定 → "1,3,4"
- 中止 → "skip"
```

4. 実行時は **`git mv` が使える場合は優先**、なければ `mv`。削除は `rm` 前に確認。

5. 完了後、検索用 `combined.txt` は hook（`ai-context-combined-rebuild.sh`）が保存時に自動再生成するため、手動操作は不要。

6. 完了レポート:

```
## 振り分け完了

- リネーム: N件
- 移動: N件
- 削除: N件
- スキップ: N件

推奨: `/ai-context status` で最終状態を確認
```

## 安全ルール（内部モード）

- `decisions/` 内の**日付があるファイルは原則触らない**（既に正規）
- `docs/research/` 内のファイルは触らない（research-agent 出力は自由形式OK）
- `README.md` / `LICENSE` 等の慣例ファイルは移動しない
- `git` 管理下で `git status` にステージ済み変更がある場合は警告

---

## プロジェクト全体モード（`/ai-context sort project`、旧 doc-sort）

プロジェクト内に散在するドキュメントを対話形式で整理する。`{base}/`（store 側の ai-context base）の外（ルート直置き / `docs/` 等）が対象。

### 対象ファイル種別
```
.md, .txt, .rst, .docx, .doc, .pptx, .xlsx, .xls, .csv, .tsv, .pdf
```
加えて `.json .yaml .yml .toml` もスキャンするが、**設定ファイル（package.json / tsconfig.json / pyproject.toml 等）はスキップ**、ドキュメント（openapi.yaml / api-spec.json 等）は対象。

### 除外ディレクトリ
```
node_modules, .git, dist, build, .next, .nuxt, __pycache__,
.ai-context/sessions,
vendor, target, .venv, venv
```

### 実行手順

**Step 1: スキャン**
- 小規模（~50 ファイル以下）: main session で `Glob` を各拡張子に実行
- 中〜大規模（50 超 / モノレポ）: `Explore` subagent に委譲（親 context への大量パス流入を防ぐ）。迷ったら Explore に倒す。

**Step 2: 分類** — 3 カテゴリでユーザーに提示:
- `[移動推奨]` ルート直置き → `docs/` への移動推奨（# / ファイル / サイズ / 推奨先 / アクション）
- `[参照のみ]` 移動不可（README / LICENSE / CHANGELOG / CONTRIBUTING / CODE_OF_CONDUCT / `.github/` 配下 / サブパッケージ README）
- `[確認]` 判断が必要（docs/ 移動 / 削除 / そのまま）

**Step 3: 対話** — `1,2` / `all` / `each` / `skip` で選択を仰ぐ。

**Step 4: 実行** — `git mv` 優先（なければ `mv`）。`docs/` 無ければ作成。

**Step 5: 検索対象の登録提案** — `docs/` 等が `config.json` の `extra_docs_dirs` に未登録なら登録を提案 → yes で `extra_docs_dirs` に追加（次回の hook 再生成で `combined.txt` に反映される。手動再構築は不要）。

**Step 6: 参照インデックス生成** — 全ドキュメントの索引を `<base>/docs/[Index] project-documents.md` に保存（docs/ / ルート（移動不可）/ サブパッケージ の 3 テーブル）。

**Step 7: 完了報告** — 移動 / スキップ / 削除 / 検索対象登録（`extra_docs_dirs` 追加）のサマリ。
