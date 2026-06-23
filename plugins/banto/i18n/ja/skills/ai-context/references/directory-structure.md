# ディレクトリ構造（AI 管轄領域）

> このファイルは**外部ツール向けの read 契約**を兼ねる（README からリンク）。バケット名・
> プレフィックス・gitignore 区分は互換性面として扱い、変更時は CHANGELOG に明記する。

## store layout（基準）

knowledge は中央 store に集まり、repo は code だけを持つ（store-first）。

```
<store_root>/                      # 既定 ~/ai-context-store（AI_CONTEXT_STORE_ROOT で変更可）
├── .ai-context-store              # marker（code repo との誤認防止。store 識別子）
├── .mapping.json                  # cwd → project 解決表（per-machine・store には commit しない）
├── _shared/                       # プロジェクト横断の共有知識
└── <project>/                     # 1 プロジェクト = 1 dir（scaffold が登録・生成）
    └── … 下記バケット
```

```
<base>/                  # = <store_root>/<project>/（SessionStart が絶対パスを注入）
├── decisions/           # 設計判断ログ（フラット・ファイル名に author 帰属）← store 共有
├── docs/                # 報告・記録系（フラット）           ← store 共有
│   └── research/        # research-agent 出力               ← store 共有
├── learnings/           # 教訓・学び（個人状態）             ← store 共有
│   └── <author>/        #   メンバー名前空間
├── workspaces/          # WS 単位の作業状態（新 layout・個人状態）← store 共有
│   └── <author>/        #   メンバー名前空間
│       └── [scope] topic/
│           ├── workspace.md   # WS 定義（ブランチ/依存/関連doc）
│           ├── tasks.md       # この WS の active タスク（旧 active.md 相当）
│           └── tasks-old/     # Phase 退避（旧 tasks/old 相当）
├── tasks/               # legacy タスク管理（未移行案件のみ）← store 共有
│   ├── active.md
│   └── old/             # 完了済み（YYYY-MM-DD_phase-name.md）
├── sessions/            # チェックポイント（個人状態）
│   ├── pending/<author>.md     # 未取込チェックポイント（旧 checkpoints/pending.md を移設）← store .gitignore
│   └── consumed/<author>/      # 取込済みチェックポイント（per-author）              ← store .gitignore
├── WORKSPACE.md         # 軽量ポインタ（per-checkout）       ← store .gitignore
├── DASHBOARD.md         # hook 管理の鳥瞰図（per-checkout）  ← store .gitignore
└── *-combined.txt       # 検索用テキスト層（hook が自動再生成）← store .gitignore
```

**帰属の原則**:
- **共有知識（`decisions/` / `docs/`）= フラット**。誰のものかはファイル名の author 帰属（`..._{github-account}.md`）で表す。
- **個人状態（`tasks/` / `sessions/pending` / `sessions/consumed` / `learnings/` / `workspaces/`）= `<author>/` scope** で名前空間を分離し、メンバー間で衝突しない。
- 旧 `checkpoints/` バケットは廃止。`checkpoints/pending.md` は `sessions/pending/<author>.md` へ移設。

- **grandfather（legacy）**: 既存の repo 内 `.ai-context/` を持つ案件は、移行
  （`/ai-context migrate`）まで同じバケット構造を repo 内 base で使い続ける（読み書き従来どおり）。
  新規生成はされない。
- store の gitignore 区分は `<store_root>/.gitignore` で一元管理（per-project .gitignore なし）。

**プロジェクトの本筋ドキュメント（`docs/requirements.md` 等）には触れない。**

| 配置 | 用途 |
|------|------|
| `decisions/` | 設計判断ログ（共有・フラット・ファイル名 author 帰属） |
| `docs/` 直下 | 報告・記録系（共有・プレフィックス必須） |
| `docs/research/` | research-agent の調査結果（共有） |
| `learnings/<author>/` | 教訓・学び（個人状態） |
| `workspaces/<author>/<topic>/tasks.md` | 進行中タスク（新 layout、WS に束ねる） |
| `workspaces/<author>/<topic>/tasks-old/` | 完了済みフェーズ（新 layout） |
| `tasks/active.md` / `tasks/old/` | legacy（未移行案件の読取フォールバック先） |
| `sessions/pending/<author>.md` | 未取込チェックポイント（旧 `checkpoints/pending.md`） |
| `sessions/consumed/<author>/` | 取込済みチェックポイント |

## docs/ 直下の固定プレフィックス

`docs/research/` 以外は**必ず**以下のプレフィックスを使う。hook で強制される。

```
[Status]      ステータス報告、進捗報告、状況報告
[Design]      設計検討、計画、提案、議論ドラフト（decision の手前の検討物）
[Guide]       説明資料、概説、手順、アーキ解説、オンボーディング
[Audit]       監査・分析・棚卸し（セキュリティ/パフォーマンス監査、比較、インベントリ）
[Review]      コードレビュー結果
[QA]          QAテストレポート、E2E結果
[Memo]        短いメモ、覚書、記録
[Index]       他ドキュメントの参照インデックス（真の索引）
```

選び方: 設計・計画・提案 → `[Design]` / 説明・手順・概説 → `[Guide]` / 進捗・状況 → `[Status]` / 監査・分析 → `[Audit]`。
例: `[Design] payment-redesign-2026-06-23.md` / `[Guide] onboarding-2026-06-23.md`

**NEVER**: 新しいプレフィックスを勝手に作る。必要ならユーザーに相談。
