# Saving decisions (auto-save rules / format / secrets)

<!-- merged from auto-save-rules.md -->
## Auto-save rules

Save **immediately** when a design decision occurs. Don't wait for a commit. If the base (store / provisional local side) hasn't been created yet, scaffold creates it automatically (don't write to a relative `.ai-context/`). Don't ask for permission.

## What to save

- Decisions on design direction ("let's go with B instead of A")
- Technology selection
- Architecture changes
- Trade-off discussions and conclusions
- Root causes of problems

## What not to save

Simple implementation work, typo fixes, and plain factual answers only.

## Where to save

`{base}/decisions/YYYY-MM-DD-HHMMSS_{topic-slug}_{github-account}.md`

## Naming convention (second-precision timestamp, v5.21.4+)

- Filenames are made unique with a second-precision time (`YYYY-MM-DD-HHMMSS_topic_author`). No same-day collisions even under team concurrency or offline work (the NNN sequence number is retired)
- The recommended name is injected into context at PreToolUse by the `ai-context-decisions-numbering.sh` hook
- Existing files in the old `YYYY-MM-DD_NNN_` (sequence-number) format stay valid (no rename needed)

## Procedure for deciding the filename

1. The PreToolUse hook shows the "recommended filename (second-precision timestamp)"
2. Write `YYYY-MM-DD-HHMMSS_{topic}_{user}.md` under that name
3. The PostToolUse hook validates the naming convention (if it starts with a date but is otherwise off-convention, it suggests a recommended `git mv`)

For the GitHub account name use `gh api user --jq '.login'`, falling back to `git config user.name` on failure.

<!-- merged from decision-log-format.md -->
## Decision Log format

## Lightweight (small decisions)

```markdown
## {タイトル}

- **日付**: YYYY-MM-DD
- **タグ**: architecture, security, performance, etc.

## 判断
{何を決めたか、なぜか。2〜3行}
```

## Full (large decisions, includes Glaser friction)

```markdown
## {タイトル}: {決定内容の一行サマリー}

- **日付**: YYYY-MM-DD
- **タグ**: architecture, security, performance, etc.

## 出発点
{なぜこの判断が必要になったか}

## 検討した選択肢

| 選択肢 | メリット | デメリット |
|---------|----------|------------|
| A | ... | ... |
| B | ... | ... |

## 決め手
{最終的にどれを選び、なぜか}

## 捨てた理由
{他の選択肢を不採用にした理由}

## フリクション（着手前/着手中の違和感・遠回り、Glaser 反映）
{失敗・遠回り・「ここで詰まった」「想定と違った」を残す。学習の本体}

## 学んだこと
{次回に活かせる知見、再利用可能なパターン、回避すべき落とし穴}
```

## Why leave friction in (from Robert Glaser's "When Everyone Has AI")

> "By the time the story is cleaned up enough to become a best-practice slide, the important learning has often lost its teeth. What made it useful was the friction: the missing context, the test that failed, the weird API behavior, the moment where the agent sprawled into nonsense and someone had to pull it back."

Recording only "the reason it was adopted" hollows out the explicit knowledge. Leaving friction (failures, things that felt off) is the essence of organizational learning.

Details: https://www.robert-glaser.de/when-everyone-has-ai-and-the-company-still-learns-nothing/

<!-- merged from secrets.md -->
## Handling secrets

## When saving (decisions/, checkpoints, etc.)

Do **not** write tokens like the following into decision logs or checkpoints:
`sk-*`, `ghp_*`, `Bearer *`, values inside `.env`, API keys, connection strings, and the like.
When needed, replace them with a placeholder like `{SECRET}` or `[MASKED]`.

## When displaying (terminal / chat output)

The risk of it staying in chat history is the same as when saving. Always mask values when printing them via Bash too:

- **Forbid raw output** like `cat .env` / `diff .env .env.old` / `grep = .env`
- When values are needed, print key names only with `sed 's/=.*/=***/' .env`
- For diffs, mask both sides before running `diff`
- Restrict `grep` to prefixes (e.g. `grep "^AWS_"`) so token-like values (`*_TOKEN`, `*_API_KEY`, `*_SECRET`, `Bearer *`) aren't swept in
- **No debug traces**: `bash -x` / `set -x` / `env` / `printenv` / `declare -p` leak `.env`-derived values into the trace, which then stays in chat. Print only the length of an individual variable with `echo "KEY=[${#VAR} chars]"`, or substitute a stub like `LAMBDA_API_KEY=dummy bash script.sh`

See `~/.claude/rules/safety.md` (deployed by harness-setup.sh) for details.

## If a secret gets exposed

If a value ends up in chat history, logs, or files, notify the user immediately and **strongly recommend revoke / rotation**. Deleting it from history alone isn't enough (external caches may remain).
