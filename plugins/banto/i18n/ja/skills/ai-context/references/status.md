# /ai-context status — 状態表示詳細

## 目的
現在の `.ai-context/` に何が格納されているかを**読むだけ**で表示。

> store-first: BASE 解決は SKILL.md 冒頭のとおり。以下の `.ai-context/` は解決した `$BASE/` に読み替える。

## 実行手順

Glob と `wc -l` 等で各種カウントを取得:

```bash
test -d .ai-context && echo "✓" || echo "✗ .ai-context/ が存在しません"

find .ai-context/decisions -maxdepth 1 -name "*.md" 2>/dev/null | wc -l
find .ai-context/decisions -maxdepth 1 -name "$(date +%Y-%m-%d)_*.md" 2>/dev/null | wc -l

find .ai-context/docs/research -maxdepth 1 -name "*.md" 2>/dev/null | wc -l

find .ai-context/sessions -maxdepth 1 -name "*.md" 2>/dev/null | wc -l

test -f .ai-context/tasks/active.md && {
    grep -c "^- \[ \]" .ai-context/tasks/active.md
    grep -c "^- \[x\]" .ai-context/tasks/active.md
}

test -f .ai-context/WORKSPACE.md && head -1 .ai-context/WORKSPACE.md
find .ai-context/workspaces -maxdepth 1 -name "*.md" 2>/dev/null | wc -l

ls .ai-context/*-combined.txt >/dev/null 2>&1 && echo "✓ 生成済み" || echo "✗ 未生成"
```

## 出力フォーマット

```
## .ai-context/ の状態

### 基本
- ルート: {存在 / 欠損}
- .gitignore: {AI Context 登録済み / 未登録}

### コンテンツ
| 領域 | 件数 | 備考 |
|---|---|---|
| decisions/ | N件 (本日: M件) | 最新: YYYY-MM-DD_... |
| docs/research/ | N件 | 最新: ... |
| sessions/ | N件 | （一時的） |
| tasks/active.md | 未完 X / 完了 Y | Phase: ... |

### ワークスペース
- WORKSPACE.md: {あり / なし} → {現在のWS名}
- workspaces/: N件

### 検索テキスト層（combined.txt）
- *-combined.txt: {生成済み / 未生成。hook が保存時に自動再生成}

### 推奨アクション
（該当するものだけ表示）
- 未生成 → /ai-context init を推奨
- WS未設定 → /ws new を推奨
- 不整合あり → /ai-context doctor を推奨
- active.md が肥大（>200行）→ /ai-context tasks split を推奨
```
