---
name: banto-port
description: |
  非公開の開発リポジトリから公開 Banto ツリーへ、変更を安全にポートする: allowlist レビュー → naming / i18n / hygiene → ゲート一式（brand gate / NDA 走査 / syntax / unit tests / clean-room）→ export。各ステップは明示的な PASS 条件を持つ deterministic なコマンドなので、能力の低いモデルでも安全に回る。公開（commit / push）は常に人間ゲート。
  トリガー: 「公開ツリーへ反映して」「public export 流して」「公開用にポートして」「公開ゲート一式回して」。/banto-port でも呼び出し可能。「リリース」「出して」「公開して」では絶対に発火しない — それらは ws ship インテント（別物の、人間ゲート付き操作）であり、banto-port は公開 export の PORT 手順であって publish アクションではない。
  使わない場面: 品質監査（plugin-audit / harness-audit）、単一ファイルの編集（直接 Edit）、GitHub への公開（owner の手動ゲート、対象外）、main へのマージ / リリース（ws ship）。
user-invocable: true
argument-hint: "[export-target-dir（省略時は /tmp/banto-public-export）]"
allowed-tools: Read Write Edit Glob Grep Bash
compatibility: Claude Code (requires bash, git, jq; docker optional for clean-room)
---

# Banto Port — 非公開 → 公開 ポート手順

**WORKFLOW SKILL**

ユーザーが日本語で会話している場合は、日本語で応答する。

各ステップを**順番に**実行する。各ステップはコマンドと PASS 条件を明示する。あるステップが FAIL したら、**停止し、修正し、そのステップを再実行する** — 失敗ゲートを飛び越えて先に進んではならない。採用解釈は最後に報告する（spec-fidelity）。

リポジトリルート: `plugins/banto/` と `scripts/export-public.sh` を含むチェックアウト。以下のコマンドはすべてリポジトリルートから実行する。

## Step 0: Preflight

```bash
git status --porcelain        # PASS: empty (commit or stash everything first)
git branch --show-current     # record the branch in the final report
```

ワーキングツリーが dirty な場合: 停止して、先に commit するかをユーザーに尋ねる。dirty なツリーからのポートは export を再現不能にする。

## Step 1: Allowlist review (default-deny)

`scripts/export-public.sh` を開き、`ALLOW` リストと `PLUGIN_EXCLUDE` を読む。

- リストに**ない**ものは**export されない**（NDA-safe なデフォルト）。新規のトップレベルファイルは、意識的に追加されるまで非公開のまま。
- チェック: `git log --name-only --since="2 weeks ago" -- . ':!plugins'` — 公開すべき新規トップレベルファイル/ディレクトリが現れたら、`ALLOW` にテキストとして追加することを提案し、適用する。そうでなければ非公開のままにする（アクション不要）。
- `ALLOW` に絶対に追加しないもの: `catalog.tsv` / root `skills/`（standalone）/ `CHANGELOG.md`（内部履歴）/ `.claude/` / 監査 artifact。

## Step 2: Porting conventions (apply to any content being ported)

1. **Naming**: legacy ブランド名を含めない。
2. **i18n**: description とユーザー向けメッセージは EN canonical。skill description 内の日本語トリガーフレーズは**そのまま**保持する（それらはルーティング契約）。hooks/scripts に消費されるトークンはバイトを保持する（`i18n: consumed-by` のノートを探す）。
3. **Hygiene (Axis 14)**: 内部名 / クライアント名 / 個人の絶対パス（`/Users/<real-name>`）を含めない。貼り付けた実行出力（ターミナルの結果行、タイムスタンプ、ツールの tmp パス）も、公開ドキュメントへの内部 decision ファイルへのポインタも含めない。プレースホルダ（`/Users/you/...`、"Person A"、"Company X"）を使う。
4. **Shell**: POSIX sh のみ（`#!/bin/sh`、bash 配列なし、`&>` なし）。GNU-first のコマンドフォールバック（例: `stat -c %Y ... || stat -f %m ...`）— CI は dash/GNU 上で動く。

## Step 3: Gate suite (all must PASS before export)

```bash
sh scripts/check-legacy-names.sh --code   # PASS: "OK: no legacy brand names found (scope: --code)"
sh scripts/check-legacy-names.sh          # PASS: "OK: ... (scope: full)"
for f in $(git ls-files '*.sh'); do sh -n "$f" || echo "SH FAIL: $f"; done   # PASS: no FAIL lines
for f in $(git ls-files '*.json'); do jq empty "$f" || echo "JSON FAIL: $f"; done  # PASS: no FAIL lines
sh plugins/banto/scripts/test-ai-context-paths-wiring.sh   # PASS: "ALL GREEN"
sh plugins/banto/scripts/test-resolve-store-path.sh        # PASS: "ALL GREEN"
```

## Step 4: Export (allowlist copy + internal gates re-run)

```bash
TARGET="${1:-/tmp/banto-public-export}"   # $ARGUMENTS first token; target must not exist
rm -rf "$TARGET"
sh scripts/export-public.sh "$TARGET"
```

PASS: `Export ready: ... (N files staged, NOT committed)` で終わり、export 内の両ゲートが OK を表示する。N を記録する（baseline: 194; 大きく説明のつかない増減があれば調査する）。

## Step 5: NDA sweep on the export (registry + manual patterns)

```bash
cd "$TARGET"
grep -rnE '[A-Za-z0-9._+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' . --exclude-dir=.git | grep -vE 'noreply@anthropic|example\.com'
grep -rnE '/Users/[a-z]+|/home/[a-z]+' . --exclude-dir=.git | grep -vE '/Users/(you|me|<)|/home/(you|me|<)'
```

PASS: 両コマンドとも**何も出力しない**。`~/.claude/banto-name-registry` が存在する場合は、追加で export を各レジストリエントリで grep する（PASS: 0 hits）。レジストリが存在しない場合は、レジストリチェックが no-op だったことをレポートに記す。

## Step 6: Clean-room (if docker is available; otherwise note as skipped)

```bash
docker run --rm -v "$TARGET":/src:ro -v "$PWD/scripts/clean-room-test.sh":/t.sh:ro ubuntu:24.04 sh /t.sh
```

PASS: 最終行が `CLEAN-ROOM: ALL PASS`（9 カテゴリ: syntax on dash / jq / py / yaml / brand gates / unit tests / audit pipeline / hook synthetic payloads / state migration）。

## Step 7: Report (and stop — publishing is the human gate)

テキストで報告する: branch / file count / gate results / NDA sweep result / clean-room result / 採用解釈。その後**停止する**:

- export ターゲット内で `git commit` してはならない。`git push` も、GitHub リポジトリの作成・変更もしてはならない。export ディレクトリは設計上 staged-only であり、review → commit → publish は owner の手動判断。

## Prohibited

- 失敗ゲートの skip や、FAIL を飛び越えたステップの並べ替え
- 非公開 skill / 内部 artifact の allowlist への追加
- export の push や publish（人間ゲート）
- brand gate の弱体化（exclusion の削除）
