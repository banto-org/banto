# /ws multi モード（複数 WS 並列参照）

複数の研究テーマや実験を**同一ブランチ上で同時に参照**するモード（単一 checkout 限定 — `WORKSPACE-refs.md` は store 直下のため、並走 worktree 間では共有される点に注意）。最初の引数が primary（書き込み対象）、残りは reference（参照専用）。

## /ws multi <ws1> <ws2> ...: 複数 WS を並列参照

### Step 1: 引数パース

```
primary="<ws1>"
references="<ws2> <ws3> ..."
```

### Step 2: primary の実効ポインタ（`<git-dir>/banto-ws-pointer.md`、非 git は WORKSPACE.md）を書き換え

`/ws switch <ws1>` と同じ手順（ポインタ Write + branch 自動切替）だが、**未コミット変更があっても警告のみ**（multi はドラフト中心なので許容）。

### Step 3: 参照 WS の情報を `{base}/WORKSPACE-refs.md` に書き込み

```markdown
# Workspace References（multi モード）

**primary**: [research] topic-a（書き込み対象）

## 参照 WS（読み取り専用）

### [model] example-model-24b
（該当 workspaces/ の「関連ドキュメント」欄を要約）

### [research] topic-b
（...）

## 書き込みルール

- 決定ログ・docs/ の新規作成は **primary** に紐付ける
- references の関連ドキュメントは「参考にするのみ、直接編集しない」
- 書き込む前に「この内容はどの WS に属するか」を判断

## /ws solo で single モードに戻す
```

### Step 4: 報告

```
✓ Multi モード有効化
  Primary:    [research] topic-a（書き込み対象）
  References: [model] example-model-24b, [research] topic-b（参照のみ）

書き込みは primary に紐付けてください。
single モードに戻すには /ws solo。
```

## /ws solo: multi モードを解除

```bash
rm -f "{base}/WORKSPACE-refs.md"
```

primary の実効ポインタ（`<git-dir>/banto-ws-pointer.md`、非 git は WORKSPACE.md）はそのまま、references だけ削除。報告: 「single モードに戻しました。primary: [scope] topic」。

## multi モードの hook 連携（設計メモ）

`ai-context-workspace-check.sh` hook は以下を判定する:
- `{base}/WORKSPACE-refs.md` が存在する → multi モード
- 新規ファイル作成時、primary / reference のどちらに紐付くか AI に問い合わせ
- references 側に書き込む場合は「primary に紐付けるべきでは？」と確認

（hook 側の実装は別タスク T3.10 として次ラウンド）
