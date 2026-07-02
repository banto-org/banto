# ディレクトリ構造（store layout の正本）

> このファイルは **store layout の正本（canonical）**。各 skill / hook はパスを再掲せず、ここへ
> リンクする。バケット名・プレフィックス・gitignore 区分は外部ツール向けの read 契約も兼ねるため、
> 変更時は CHANGELOG に明記する。
>
> **機械可読版（単一ソース）**: `templates/store-layout.json`。`scripts/store-map-lint.sh` が
> 「skill/odd の宣言 ↔ 本マニフェスト ↔ 実体ファイルシステム ↔ 本表」の四者一致を毎回検証し、
> `scripts/store-map-gen.sh` が `meta/store-map.md` に生きた地図（フォルダ↔skill↔hook↔実体件数）を出力する。
> バケットを増減するときは **本ファイルと store-layout.json を同時に**編集する（リンターが乖離を弾く）。

`{base}` は SessionStart / PreCompact hook が「ai-context ベース: &lt;絶対パス&gt;」として注入する
ベース絶対パス（= `<store_root>/<project>/`）。本ファイル内の `{base}/...` はすべてこのベース配下を指す。
不明なときは `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"` で解決する。

## store root layout（基準）

knowledge は中央 store に集まり、repo は code だけを持つ（store-first）。

```
<store_root>/                      # 既定 ~/ai-context-store（AI_CONTEXT_STORE_ROOT で変更可）
├── .ai-context-store              # marker（code repo との誤認防止。store 識別子）
├── .mapping.json                  # cwd → project 解決表（per-machine・store には commit しない）
├── _shared/                       # プロジェクト横断の共有知識（decisions / docs）
└── <project>/                     # 1 プロジェクト = 1 dir（resolver が初回 write で生成）
    └── … 下記バケット（= {base}）
```

非ブロッキング仮ローカル（未登録 repo で SessionStart が即用意・後で bootstrap で移行）:

```
~/ai-context-local/<project>/      # 中央 store と同一構成の仮置き。bootstrap で store へ移行、
                                   # または `/ai-context local` でローカル固定（mapping local:true）
```

## {base} layout（プロジェクト配下の全バケット）

```
{base}/                  # = <store_root>/<project>/（SessionStart が絶対パスを注入）
├── decisions/           # 設計判断ログ（フラット・ファイル名に author 帰属）  ← store 共有
├── docs/                # 報告・記録系（フラット・プレフィックス必須）          ← store 共有
│   ├── research/        #   research-agent の調査出力                          ← store 共有
│   ├── knowledges/      #   昇格済みナレッジ（プレフィックスなし例外）          ← store 共有
│   │   └── drafts/      #     ナレッジ下書き（hook が自動保存・閾値でレビュー） ← store .gitignore
│   └── refs/            #   所在カード（外部文書のポインタ + 相関。本文は持たない）← store 共有
├── learnings/           # 教訓・学び（教訓 scope。個人状態）                    ← store 共有
│   └── <author>/        #   メンバー名前空間（Stop hook 自己改善が書く）
├── meta/                # store 自身のメタ（新 scope）                          ← store 共有
│                        #   マッピング / 索引 / health lint レポート等
├── tasks/               # legacy タスク管理（未移行案件の読取フォールバック）   ← store 共有
│   ├── active.md
│   └── old/             #   完了済み（YYYY-MM-DD_phase-name.md）
├── sessions/            # チェックポイント（個人状態）                          ← store .gitignore
│   ├── pending/<author>.md       #   未取込チェックポイント + 例外チャネル
│   ├── consumed/<author>/        #   取込済みチェックポイント（per-author）
│   └── registry/<id>.json        #   Fleet セッション台帳（衝突検知・7日 GC）   ← store .gitignore
├── sessions-cache/<id>.txt       # full-combined 用の会話キャッシュ             ← store .gitignore
├── telemetry/usage-YYYY-MM.jsonl # 月次テレメトリ（skill 起動 / artifact・PII ゼロ）← store 共有
├── config.json          # per-project 検索設定（extra_docs_dirs）              ← store 共有
├── workspaces/          # WS 単位の作業状態（新 layout・個人状態）              ← store 共有
│   └── <author>/        #   メンバー名前空間
│       └── [scope] topic/
│           ├── workspace.md      #   WS 定義（ブランチ / 依存 / 関連 doc）
│           ├── tasks.md          #   この WS の active タスク（旧 active.md 相当）
│           └── tasks-old/        #   Phase 退避（旧 tasks/old 相当）
├── WORKSPACE.md         # 非 git 環境のポインタ fallback（本体は <git-dir>/banto-ws-pointer.md）← store .gitignore
├── DASHBOARD.md         # hook 管理の鳥瞰図（per-checkout）                     ← store .gitignore
└── *-combined.txt       # 検索用テキスト層（hook が自動再生成）                 ← store .gitignore
```

**帰属の原則**:
- **共有知識（`decisions/` / `docs/`）= フラット**。誰のものかはファイル名の author 帰属
  （`..._{github-account}.md`）で表す。
- **個人状態（`learnings/` / `sessions/pending` / `sessions/consumed` / `workspaces/`）= `<author>/` scope**
  で名前空間を分離し、メンバー間で衝突しない。
- 旧 `checkpoints/` バケットは廃止。`checkpoints/pending.md` は `sessions/pending/<author>.md` へ移設。
- **教訓 scope `learnings/`**: 教訓・学び。Stop hook 自己改善ループ（`ai-context-stop-self-improve.sh`）が
  `learnings/<author>/` に書き、SessionStart が読む。skeleton にも含める（従来の暗黙ディレクトリを明示化）。
- **新 scope `meta/`**: store 自身のメタ情報（フォルダ↔skill マッピング・索引・health lint レポート）。
  プロジェクトの知識ではなく store 運用のための領域。`store-map-gen.sh` が `meta/store-map.md` を生成する。
- **遅延生成（lazy）バケット**: 特定 skill が初回実行時にだけ掘るため、未起動なら実体は無い（リンターは欠落を許容）。
  `docs/specs/`（spec）/ `concept/CONCEPT.md`（concept）/ `experiments/<project>/ledger.jsonl`（model-lab）/
  `tmp/search/`（search の一時出力・gitignore）/ `search-lexicon.md`（search が deep 成功時に追記）/
  `tasks/`（legacy 読取フォールバックのみ・新規生成なし）/ `WORKSPACE.md`（非 git 環境のポインタ fallback。
  本体は `<git-dir>/banto-ws-pointer.md`）。旧 `refs/`（doc-import）は 5.75.10 で廃止。

- **grandfather（legacy）**: 既存の repo 内 `.ai-context/` を持つ案件は、移行（`/ai-context migrate`）
  まで同じバケット構造を repo 内 base で使い続ける（読み書き従来どおり）。新規生成はされない。
- store の gitignore 区分は `<store_root>/.gitignore` で一元管理（per-project .gitignore なし）。

**プロジェクトの本筋ドキュメント（`docs/requirements.md` 等）には触れない。**

## マッピング表（フォルダ → 書く skill/hook → prefix/形式）

> 「どのフォルダに、どの skill / hook が、どのプレフィックス / 形式で書くか」の正本。
> 各 skill はこの表を参照し、保存先・命名を二重定義しない。

| フォルダ | 書く skill / hook | prefix / 形式 |
|---|---|---|
| `decisions/` | `ai-context`（決定記録）/ `spec`・`dev-loop`（決定の派生）| プレフィックスなし。`YYYY-MM-DD-HHMMSS_<slug>_{github-account}.md`（フラット・author 帰属）|
| `docs/`（直下）| `memo`（`ai-context memo`）/ `status` / `harness-audit` / `plugin-audit` / `qa-tester`（呼出元が保存）| 下記「固定プレフィックス」必須。例 `[Memo] ...` / `[Status] ...` / `[Audit] ...` |
| `docs/research/` | `research`（`research-agent` が出力）| `YYYY-MM-DD_<topic>.md`（プレフィックスなし）|
| `docs/knowledges/` | `knowledge`（`ai-context knowledge`）昇格先 | プレフィックスなし（**例外**）。タイトル = ファイル名 `{topic}.md` |
| `docs/knowledges/drafts/` | `ai-context-auto.sh`（hook が自動保存）→ `knowledge` でレビュー / 昇格 | `{topic}.md`。閾値（`BANTO_DRAFT_REVIEW_MIN` 既定 10）超で SessionStart が提示 |
| `docs/refs/` | `ai-context`（会話の所在登録）/ `ref_scan.py`（一括棚卸し）| `[Ref] <名前>.md`。frontmatter = source / uri / fetched / related。本文は要旨のみ（ミラー禁止）|
| `learnings/<author>/` | `ai-context-stop-self-improve.sh`（Stop hook 自己改善ループ）/ SessionStart（読取・注入）| 教訓ドラフト（per-author） |
| `meta/` | store 運用（マッピング / 索引 / `ai-context-lint.sh` の health レポート）| 形式は用途別（索引 / レポート）|
| `tasks/active.md`・`tasks/old/` | `ai-context`（legacy 運用・未移行案件のみ）| `active.md` / `old/YYYY-MM-DD_phase-name.md` |
| `sessions/pending/<author>.md` | `save-checkpoint`（保存）/ SessionStart（取込）| `checkpoint-{YYYY-MM-DD}-{HHMM}.md` 相当。pending → consumed へ遷移 |
| `sessions/consumed/<author>/` | SessionStart（取込済みへ移動）| 取込済みチェックポイント（per-author）|
| `workspaces/<author>/[scope] topic/` | `ws`（WS 定義・active タスク）| `workspace.md` / `tasks.md` / `tasks-old/`（新 layout）|
| `WORKSPACE.md`・`DASHBOARD.md` | `ws`（非 git fallback / multi 参照）/ 管理 hook | ポインタ fallback・鳥瞰図（gitignore）。ポインタ本体は `<git-dir>/banto-ws-pointer.md` |
| `sessions/registry/` | `session-registry.sh`（Fleet 台帳）| `<session_id>.json`。衝突検知 12h 窓・7日 GC（gitignore）|
| `sessions-cache/` | `ai_context_combined.py`（full-combined 用キャッシュ）| `<session_id>.txt`（gitignore）|
| `telemetry/` | `telemetry-log.sh`（skill 起動 / artifact 記録）| `usage-YYYY-MM.jsonl`。basename / prefix のみ・PII ゼロ |
| `config.json` | `ai-context` / `search`（per-project 検索設定）| `extra_docs_dirs` 等。`ai_context_combined.py` / `ai_context_search_rank.py` が読む |
| `docs/specs/` | `spec`（SDD 三点）| `YYYY-MM-DD_<slug>_(spec\|plan\|tasks).md`（lazy）|
| `concept/` | `concept`（North Star）| `CONCEPT.md`（lazy・固定名）|
| `experiments/<project>/` | `model-lab`（claim 台帳）| `ledger.jsonl`（lazy）|
| `meta/` | `store-map-gen.sh`（フォルダ↔skill 地図）| `store-map.md`（+ 索引 / health レポート）|

## docs/ 直下の固定プレフィックス

`docs/research/` と `docs/knowledges/`（プレフィックスなし例外）以外は**必ず**以下のプレフィックスを使う。
hook で強制される。

```
[Status]      ステータス報告、進捗報告、状況報告
[Design]      設計検討、計画、提案、議論ドラフト（decision の手前の検討物）
[Guide]       説明資料、概説、手順、アーキ解説、オンボーディング
[Audit]       監査・分析・棚卸し（セキュリティ / パフォーマンス監査、比較、インベントリ）
[Review]      コードレビュー結果
[QA]          QA テストレポート、E2E 結果
[Memo]        短いメモ、覚書、記録
[Index]       他ドキュメントの参照インデックス（真の索引）
```

選び方: 設計・計画・提案 → `[Design]` / 説明・手順・概説 → `[Guide]` / 進捗・状況 → `[Status]` /
監査・分析 → `[Audit]`。
例: `[Design] payment-redesign-2026-06-23.md` / `[Guide] onboarding-2026-06-23.md`

**NEVER**: 新しいプレフィックスを勝手に作る。必要ならユーザーに相談。
