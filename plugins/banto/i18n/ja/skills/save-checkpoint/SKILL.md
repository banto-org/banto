---
name: save-checkpoint
description: |
  現在のセッション状態をチェックポイントとして {base}/sessions/ 配下に保存し、compact または clear を推奨する。
  トリガー: 「チェックポイント保存」「状態保存して」「clear前に保存」「compact前に保存」。/save-checkpoint でも起動可。
  使わない場面: ユーザーが状態保存を求めずに単に compact/clear に言及しただけのとき、または設計判断の記録（ai-context skill の decisions/）のとき。このスキルは /compact・/clear を決して自分で実行しない。
user-invocable: true
allowed-tools: Read Write Glob Bash
compatibility: Claude Code (requires bash, git, jq)
---

> **保存ベース（store-first）**: この skill 内の `.ai-context/...` パスはすべて ai-context ベースを指す。SessionStart/PreCompact hook が「ai-context ベース: &lt;絶対パス&gt;」として注入する絶対パス配下で Read/Write すること — 相対 `.ai-context/` には絶対に書かない（これは旧来の legacy repo にのみ存在する。不明なときは `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"` で解決）。

現在の作業状態をチェックポイントファイルとして保存する。

生成するドキュメントはユーザーの会話言語で書く（ユーザーが日本語で会話していれば日本語）。テンプレートのラベルは例示である。

## Step 1: 診断情報を収集

以下を並列で確認する:
- 決定ログ: `find {base}/decisions -name "*.md" | wc -l`（総数）
- 今日の決定: `find {base}/decisions -name "$(date +%Y-%m-%d)_*.md" | wc -l`
- 既存のチェックポイント: `find {base}/sessions -name "checkpoint-*.md" | wc -l`
- リサーチ: `find {base}/docs/research -name "*.md" | wc -l`
- 仕様ドキュメント: `docs/requirements.md`, `docs/design.md`, `docs/tasks.md`

## Step 2: チェックポイントファイルを作成

保存先: `{base}/sessions/checkpoint-{YYYY-MM-DD}-{HHMM}.md`

Write ツールで以下のフォーマットで保存する:

```markdown
# Checkpoint - YYYY-MM-DD HH:MM

## What is being worked on now
{concrete description including file/component names. 3-5 lines.
 Write so that a post-compaction AI can understand "why this work was being done"}

## How this work got here
{key turning points from the user's initial request to now. Chronological. 2-4 lines}

## Confirmed design decisions
{what was decided in this session. If already saved to decisions/, reference the filename;
 otherwise include the content. Bullet list}

## Open issues
{what is still undecided, what needs the user's confirmation. Bullet list}

## Recently changed files
{list of changed/created files}

## Next steps
{what to do next to continue this work. 1-2 lines}
```

## Step 3: compact / clear のどちらか一方だけを推奨

**両論併記は絶対にしない。常にどちらか一方だけを推奨する。**

診断情報から判断する:

**clear を推奨**（すべての条件を満たすとき）:
- 決定ログが保存されている（総数 > 0 かつ 今日 > 0）
- チェックポイントを作成済み（Step 2 で）
- 未保存の重要情報がない

→ 「**clear を推奨**: 決定ログとチェックポイントが保存済みなので、clear して再開しても安全です。1M コンテキストをまるごと取り戻せます。」

**compact を推奨**（clear の条件を満たさないとき）:

→ 「**compact を推奨**: {具体的な理由}。情報損失を避けるため compact を使ってください。」

## Step 4: ユーザーに確認

診断情報と推奨を提示したあと、必ず以下のフォーマットで確認する:

```
## Checkpoint created

### Diagnostics
- Decision logs: N (M today)
- Checkpoint: created ✓
- Research: N
- Specs: {requirements.md ✓/✗}, {design.md ✓/✗}, {tasks.md ✓/✗}

### Recommendation: [clear / compact]
{1-2 lines of reasoning}

Does this match your understanding? Tell me if anything is off.
If not, I will proceed with the recommended [clear / compact].
```

## Step 5: ユーザーの指示に従う

- 「OK」「合ってる」→ ユーザー自身が compact/clear を実行するのを待つ（AI は実行しない）
- 「違う」「直して」→ チェックポイントファイルを更新し、再度確認する
- 「もう一方にして」→ 推奨を反転して再提示する

## Notes

- PreCompact hook がチェックポイントを自動注入してから削除するので、次のセッションは自動的に再開される
- AI は /compact や /clear を決して自分で実行しない。ユーザーの判断を待つ
