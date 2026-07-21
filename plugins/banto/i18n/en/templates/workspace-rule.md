# Workspace Rules

## Autonomous detection of topic switches

When the user's statement clearly falls outside the scope of the current workspace (the
`# Workspace: [scope] topic` line in WORKSPACE.md):

1. Check whether a matching WS already exists under `{base}/workspaces/` (`Glob`)
2. If it exists → propose "Switch to {WS name}?" (point to `/ws switch`)
3. If not → propose "Create a new workspace `[scope] new-topic`?" (point to `/ws new`)
4. When the judgment is unclear, skip it (avoid false positives)

## Automatic update of related documents

When a **new file is created** under `{base}/decisions/` or `{base}/docs/`:

1. Judge whether it relates to the current WS's scope
2. Related → propose adding it to WORKSPACE.md's 「## 関連ドキュメント」 (related documents) section
3. Unrelated → don't add it
4. When the PostToolUse hook notifies "not registered in WORKSPACE.md", decide one of
   add/replace/skip

## Keeping the workspace fresh (strikethrough rule)

When saving a new decision / spec makes statements in the current workspace.md body
(purpose / policy / notes / related-doc descriptions) **stale**:

1. Never delete the old line — strike it through (`~~old text~~`) and append `→ 最新: {relative path of the new file} (YYYY-MM-DD)` right after it
2. Touch only the lines that **contradict** the new decision / spec (leave unrelated lines alone)
3. When the PostToolUse hook emits a "[Workspace freshness]" notice, review workspace.md with this procedure

## Session lifecycle

- **At session start** (via the SessionStart hook): grasp the content of the injected
  WORKSPACE.md and reflect it in subsequent work
- **After `/ws switch`**: always `Read` the new WORKSPACE.md into context
- **On clear/compact**: recommend "continue/archive" for the WS, with a reason

## Forbidden

- Don't break the WORKSPACE.md format (`# Workspace: [scope] topic` / `ブランチ:` / `依存:` /
  `## 関連ドキュメント`)
- Don't add out-of-scope file references on your own
