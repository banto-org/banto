# 3 層の責務分離 / ディレクトリ構成

## 3 層の責務分離

| 機能 | 用途 | ディレクトリ | ブランチ | WORKSPACE.md |
|---|---|---|---|---|
| `/ws switch <name>` | **作業文脈の完全切替**（コミット単位の重作業） | 同一 | **自動切替**（workspace.md の「ブランチ:」に従う） | 軽量ポインタ書換え（単一） |
| `/ws multi <ws1> <ws2>` | **同ブランチ内の並列参照**（research/experiment 等、コミットしないドラフト中心） | 同一 | 切り替えない | primary 1 つ + `WORKSPACE-refs.md` に reference |
| `claude -w <name>` | **物理分離**（別ディレクトリ・別プロセス） | 別 | 自動で `worktree-<name>` | Claude Code 公式機能、banto は関与しない |

## ディレクトリ構成（新 layout）

```
<base>/                            （store: ~/ai-context-store/<project>/、grandfather legacy: repo 内 .ai-context/）
├── WORKSPACE.md                   ← 軽量ポインタ（per-checkout ローカル・gitignore。WS名+ブランチ+実体パス）
├── WORKSPACE-refs.md              ← /ws multi 時のみ存在（参照 WS の一覧・ローカル）
├── DASHBOARD.md                   ← hook 管理の鳥瞰図（ローカル・gitignore）
└── workspaces/
    └── <author>/                  ← メンバー名前空間（--author で導出）
        ├── [research] topic-b/
        │   ├── workspace.md       ← 定義（ブランチ/依存/関連doc。store 共有）
        │   ├── tasks.md           ← この WS の active タスク（旧 tasks/active.md 相当）
        │   └── tasks-old/         ← Phase アーカイブ（旧 tasks/old 相当）
        ├── [task] api-design/
        └── old/                   ← 完了 WS（cold memory）
```

**設計方針（B2）**: `WORKSPACE.md` は **symlink ではなく軽量ポインタ**（プレーンファイル）。中央 store は cwd 外にあり相対 symlink が worktree 跨ぎで壊れるため symlink を廃止（設計判断済み）。プレーンファイルなので **Windows fallback も不要**。

**legacy 互換**: 未移行案件は `workspaces/*.md` 直下（旧構成）のまま。hook が読取フォールバックで無破壊維持し、本 skill も legacy 構成を検出したら従来パスで操作する。
