# Directory structure (the canonical store layout)

> This file is the **canonical source for the store layout**. Skills / hooks don't restate paths; they
> link here. Bucket names, prefixes, and gitignore divisions also double as a read contract for external
> tools, so any change must be spelled out in the CHANGELOG.
>
> **Machine-readable version (single source)**: `templates/store-layout.json`. `scripts/store-map-lint.sh`
> verifies on every run the four-way agreement of "the skill/odd declarations ↔ this manifest ↔ the actual
> filesystem ↔ this table", and `scripts/store-map-gen.sh` emits a live map (folder↔skill↔hook↔actual counts)
> to `meta/store-map.md`. When adding or removing a bucket, edit **this file and store-layout.json together**
> (the linter rejects any divergence).

`{base}` is the absolute base path that the SessionStart / PreCompact hook injects as
"ai-context base: &lt;absolute-path&gt;" (= `<store_root>/<project>/`). Every `{base}/...` in this file
points to something under this base. When it's unknown, resolve it with
`sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`.

## store root layout (baseline)

Knowledge collects in the central store; the repo holds only code (store-first).

```
<store_root>/                      # 既定 ~/ai-context-store（AI_CONTEXT_STORE_ROOT で変更可）
├── .ai-context-store              # marker（code repo との誤認防止。store 識別子）
├── .mapping.json                  # cwd → project 解決表（per-machine・store には commit しない）
├── _shared/                       # プロジェクト横断の共有知識（decisions / docs）
└── <project>/                     # 1 プロジェクト = 1 dir（resolver が初回 write で生成）
    └── … 下記バケット（= {base}）
```

Non-blocking provisional local (SessionStart provisions it immediately for an unregistered repo; bootstrap migrates it later):

```
~/ai-context-local/<project>/      # 中央 store と同一構成の仮置き。bootstrap で store へ移行、
                                   # または `/ai-context local` でローカル固定（mapping local:true）
```

## {base} layout (all buckets under the project)

```
{base}/                  # = <store_root>/<project>/（SessionStart が絶対パスを注入）
├── decisions/           # 設計判断ログ（フラット・ファイル名に author 帰属）  ← store 共有
├── docs/                # 報告・記録系（フラット・プレフィックス必須）          ← store 共有
│   ├── research/        #   research-agent の調査出力                          ← store 共有
│   └── knowledges/      #   昇格済みナレッジ（プレフィックスなし例外）          ← store 共有
│       └── drafts/      #     ナレッジ下書き（hook が自動保存・閾値でレビュー） ← store .gitignore
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
├── WORKSPACE.md         # 軽量ポインタ（per-checkout）                          ← store .gitignore
├── DASHBOARD.md         # hook 管理の鳥瞰図（per-checkout）                     ← store .gitignore
└── *-combined.txt       # 検索用テキスト層（hook が自動再生成）                 ← store .gitignore
```

**Attribution principles**:
- **Shared knowledge (`decisions/` / `docs/`) = flat.** Who owns a file is expressed through author
  attribution in the filename (`..._{github-account}.md`).
- **Personal state (`learnings/` / `sessions/pending` / `sessions/consumed` / `workspaces/`) = `<author>/` scope**:
  namespaces are kept separate so members never collide.
- The old `checkpoints/` bucket is retired. `checkpoints/pending.md` has moved to `sessions/pending/<author>.md`.
- **Learnings scope `learnings/`**: lessons and learnings. The Stop hook self-improvement loop (`ai-context-stop-self-improve.sh`)
  writes to `learnings/<author>/`, and SessionStart reads it. Include it in the skeleton too (making the previously implicit directory explicit).
- **New scope `meta/`**: meta information about the store itself (folder↔skill mapping, indexes, health-lint reports).
  A space for operating the store, not project knowledge. `store-map-gen.sh` generates `meta/store-map.md`.
- **Lazy-generated buckets**: a specific skill digs them only on its first run, so if it hasn't run there is no actual entry (the linter tolerates the absence).
  `docs/specs/` (spec) / `concept/CONCEPT.md` (concept) / `experiments/<project>/ledger.jsonl` (model-lab) /
  `refs/<topic>/` (doc-import, legacy) / `tmp/search/` (search's temporary output, gitignore) / `search-lexicon.md` (search appends on a successful deep run).

- **grandfather (legacy)**: projects that already have an in-repo `.ai-context/` keep using the same bucket structure
  on the in-repo base until they migrate (`/ai-context migrate`) — read/write stays as before. Nothing new is generated.
- The store's gitignore divisions are managed centrally in `<store_root>/.gitignore` (no per-project .gitignore).

**Don't touch the project's mainline documents (`docs/requirements.md`, etc.).**

## Mapping table (folder → writing skill/hook → prefix/format)

> The canonical source for "which folder, which skill / hook writes to it, and with which prefix / format."
> Each skill references this table and never defines its save location / naming twice.

| Folder | Writing skill / hook | prefix / format |
|---|---|---|
| `decisions/` | `ai-context` (decision records) / `spec`・`dev-loop` (decision derivatives) | No prefix. `YYYY-MM-DD-HHMMSS_<slug>_{github-account}.md` (flat, author attribution) |
| `docs/` (top level) | `memo` (`ai-context memo`) / `status` / `harness-audit` / `plugin-audit` / `qa-tester` (caller saves) | One of the "fixed prefixes" below is required. E.g. `[Memo] ...` / `[Status] ...` / `[Audit] ...` |
| `docs/research/` | `research` (emitted by `research-agent`) | `YYYY-MM-DD_<topic>.md` (no prefix) |
| `docs/knowledges/` | `knowledge` (`ai-context knowledge`) promotion target | No prefix (**exception**). Title = filename `{topic}.md` |
| `docs/knowledges/drafts/` | `ai-context-auto.sh` (hook auto-saves) → review / promote via `knowledge` | `{topic}.md`. SessionStart surfaces them once the threshold (`BANTO_DRAFT_REVIEW_MIN`, default 10) is exceeded |
| `learnings/<author>/` | `ai-context-stop-self-improve.sh` (Stop hook self-improvement loop) / SessionStart (read / inject) | Learnings drafts (per-author) |
| `meta/` | Store operation (mapping / index / health reports from `ai-context-lint.sh`) | Format depends on the use (index / report) |
| `tasks/active.md`・`tasks/old/` | `ai-context` (legacy operation, unmigrated projects only) | `active.md` / `old/YYYY-MM-DD_phase-name.md` |
| `sessions/pending/<author>.md` | `save-checkpoint` (save) / SessionStart (ingest) | Equivalent to `checkpoint-{YYYY-MM-DD}-{HHMM}.md`. Transitions pending → consumed |
| `sessions/consumed/<author>/` | SessionStart (moves to ingested) | Ingested checkpoints (per-author) |
| `workspaces/<author>/[scope] topic/` | `ws` (WS definition, active tasks) | `workspace.md` / `tasks.md` / `tasks-old/` (new layout) |
| `WORKSPACE.md`・`DASHBOARD.md` | `ws` / management hook (per-checkout pointer) | Lightweight pointer / overview (gitignore) |
| `sessions/registry/` | `session-registry.sh` (Fleet ledger) | `<session_id>.json`. Collision detection in a 12h window, 7-day GC (gitignore) |
| `sessions-cache/` | `ai_context_combined.py` (cache for full-combined) | `<session_id>.txt` (gitignore) |
| `telemetry/` | `telemetry-log.sh` (records skill launches / artifacts) | `usage-YYYY-MM.jsonl`. basename / prefix only, zero PII |
| `config.json` | `ai-context` / `search` (per-project search settings) | `extra_docs_dirs` etc. Read by `ai_context_combined.py` / `ai_context_search_rank.py` |
| `docs/specs/` | `spec` (the SDD trio) | `YYYY-MM-DD_<slug>_(spec\|plan\|tasks).md` (lazy) |
| `concept/` | `concept` (North Star) | `CONCEPT.md` (lazy, fixed name) |
| `experiments/<project>/` | `model-lab` (claim ledger) | `ledger.jsonl` (lazy) |
| `meta/` | `store-map-gen.sh` (folder↔skill map) | `store-map.md` (+ index / health report) |

## Fixed prefixes directly under docs/

Everything except `docs/research/` and `docs/knowledges/` (the no-prefix exceptions) **must** use one of the prefixes below.
Enforced by a hook.

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

How to choose: design / plan / proposal → `[Design]` / explanation / procedure / overview → `[Guide]` / progress / status → `[Status]` /
audit / analysis → `[Audit]`.
Example: `[Design] payment-redesign-2026-06-23.md` / `[Guide] onboarding-2026-06-23.md`

**NEVER**: invent a new prefix on your own. Consult the user if one is needed.
