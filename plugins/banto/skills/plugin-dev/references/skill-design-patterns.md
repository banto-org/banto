# Skill design patterns

A collection of design patterns for creating skills / agents.

## 1. Invocation control patterns (from the table on the official Skills page)

| フロントマター | ユーザー呼出 | Claude 呼出 | コンテキスト読込 |
|---|:---:|:---:|---|
| (default) | ✓ | ✓ | description always; full body on invocation |
| `disable-model-invocation: true` | ✓ | ✗ | description not included in context; full body on invocation |
| `user-invocable: false` | ✗ | ✓ | description always; full body on invocation |

### Bidirectional (default)

```yaml
---
name: search-codebase
description: |
  **ANALYSIS SKILL** — Search the codebase semantically.
  USE FOR: codebase exploration, finding similar implementations.
  INVOKES: Read, Grep, Glob.
---
```

Users can invoke it with `/search-codebase`. Claude can also fire it automatically.
**Use for**: general information retrieval, search, analysis.

### User-only (side-effect workflows)

```yaml
---
name: deploy
description: |
  **WORKFLOW SKILL** — Deploy the application to production.
  /deploy で明示呼び出し専用。
  INVOKES: Bash(gcloud:*), Bash(kubectl:*).
disable-model-invocation: true
allowed-tools: Read Bash(gcloud:*) Bash(kubectl:*)
---
```

Runs only when the user invokes it with `/deploy`. Claude won't fire it on its own mid-conversation.
**Use for**: side-effect workflows such as commit / deploy / send.

### Claude-only (background knowledge)

```yaml
---
name: legacy-system-info
description: |
  **ANALYSIS SKILL** — Background knowledge about the legacy XYZ system.
  use proactively when: discussing legacy XYZ behavior or migration.
user-invocable: false
---
```

Not shown in the `/` menu. Claude references it automatically when it judges it relevant to the conversation.
**Use for**: domain knowledge, legacy system information, convention sets.

## 2. Skill types (official Skills page)

### Reference content

Official definition:
> "Knowledge Claude applies to the current work. Conventions, patterns, style guides, domain knowledge. Used together with conversation context."

```yaml
---
name: api-conventions
description: API design patterns for this codebase
---

When writing API endpoints:
- Use RESTful naming conventions
- Return consistent error formats
```

Characteristics:
- **Do not add** `context: fork` (official Warning: meaningless since there is no executable prompt)
- Usually default invocation settings or `user-invocable: false`
- Referenced in the normal flow of conversation

### Task content

Official definition:
> "Step-by-step instructions for a specific action (deploy, commit, etc.). Invoked directly with `/skill-name`."

```yaml
---
name: deploy
description: Deploy the application to production
context: fork
disable-model-invocation: true
allowed-tools: Bash(gcloud:*) Bash(kubectl:*)
---

## Steps
1. Run pre-deploy checks
2. Build the artifact
...
```

Characteristics:
- `disable-model-invocation: true` is an **exceptional measure** (intent-first takes priority): only for truly irreversible, outward-facing side effects, or when it unavoidably collides with high-frequency vocabulary. Non-destructive workflows (read-only / `--refresh` required / built-in human gate / approval-gated) should be **exposed with a narrow, specific NL trigger + safety boundaries** and not given DMI (north star "every feature is reachable via natural language" / decision `2026-06-10-114006`). When you do keep it, state the explicit reason in the description.
- `context: fork` allows subagent isolation
- Has clear steps

## 3. Loop design (from Glaser's Elastic Loop)

Applying Glaser's Elastic Loop concept to skill design:

### Tight Loop (synchronous co-driving)

Characteristics: the user and Claude proceed while checking behavior in turns
- User confirmation at each step
- High control, but also high cognitive load
- Suited to complex spec branching, first attempts, uncertain requirements

```yaml
---
name: spec
description: |
  **WORKFLOW SKILL** — 業界標準フォーマットで仕様書を対話生成する。
  トリガー：「設計だけ見せて」「仕様書作って」「spec」
  使ってはいけない場面：実装まで一気にやる場合は spec 後そのまま自走実装
  依存：テキスト対話で要件確認
---
```

### Loose Loop (asynchronous delegation, Dark Factory)

Characteristics: hand off intent, delegate in a loose loop, course-correct via backpressure, evaluate results
- Centered on subagent delegation (`context: fork` + the `Agent` tool)
- Keeps the parent session's token consumption down
- Suited to established patterns, routine tasks, investigation and analysis

```yaml
---
name: research
description: |
  **WORKFLOW SKILL** — 外部情報を新たに調査してドキュメント化する。
  トリガー：「調べて」「最新の〜」「リサーチ」
  使ってはいけない場面：内部検索だけなら search を使う
  依存：research-agent を Agent(subagent_type=research-agent) で並列起動。
  単純な事実確認なら webread 1 回で十分。
context: fork
agent: general-purpose
---
```

Design questions (Glaser):
- What loop size should this skill be used at?
- Where is backpressure (evaluation / course-correction points) needed?
- Which artifacts should the loop leave behind?
- How does learning propagate to the organization?

## 4. Subagent execution patterns

### context: fork + agent specification

```yaml
---
name: deep-research
description: Research a topic thoroughly
context: fork
agent: Explore
---

Research $ARGUMENTS thoroughly:
1. Find relevant files using Glob and Grep
2. Read and analyze the code
3. Summarize findings with specific file references
```

Built-in agent types:
- **Explore**: read-only, for codebase exploration
- **Plan**: investigation agent for plan mode
- **general-purpose**: complex tasks that need both exploration and modification

### Dark-Factory-style delegation (Glaser)

```
intent (skill description で明確化)
  ↓
loose loop (research-agent を background で起動)
  ↓
backpressure (`{base}/docs/research/` に保存先指定)
  ↓
evaluate (返却結果を strong scenarios で評価)
```

Leverage `run_in_background=true` to keep the parent session's token consumption down.

## 5. Dynamic context injection

Run shell commands before the skill loads with the `` !`command` `` syntax:

```yaml
---
name: pr-summary
description: PR の変更を要約
context: fork
agent: Explore
allowed-tools: Bash(gh *)
---

## PR コンテキスト
- PR diff: !`gh pr diff`
- 変更ファイル: !`gh pr diff --name-only`

上記を踏まえて要約してください。
```

For multiple lines, use a ``` ```! ``` block.
Disable with: `"disableSkillShellExecution": true`

## 6. Permission control examples

```
# 特定スキルのみ許可
Skill(commit)
Skill(review-pr *)

# 特定スキルを拒否
Skill(deploy *)

# 全スキルを拒否
Skill
```

## 7. HeavySkill 4-component (for complex workflow skills)

Skills that involve complex reasoning adopt the HeavySkill 4-component (Activation Conditions / Parallel Protocol / Deliberation / Output Constraints). For the canonical template and the criteria for applying it (skills that involve complex / judgment / analysis / design / discussion / comparison / trade-offs, etc.), see `references/heavyskill-template.md`.

## 8. Intent-first (the principle of command design)

**Don't make the user decide "which command to use."** When a skill has a command system (`/skill sub <args>`):

1. **Start the design from intent detection** — put a table of "which operation fires when the user says what in natural language" at the very top of SKILL.md. The command table comes after (as an alias list).
2. **Reachability rule** — every command must always have a path that is reachable via natural language even when the user doesn't know it exists. Include spoken examples in the trigger words of the description.
3. **Split autonomy by intent type** — bookkeeping (syncing, cleanup, state updates) = silent and automatic (L3) / structure-creating (new branches, new file sets) = a proposal with an adopted interpretation (L2) → promote based on the misfire rate observed via telemetry / irreversible, outward-facing (PR, publish, send) = human gate.
4. **Write misfire guards** — state the "does not fire on this utterance" boundary (to prevent bureaucratization) explicitly in SKILL.md.
5. Keep the commands — deterministic, callable from routine/CI, and for power users. What's bad is "making them the primary interface," not their existence.

Example: `skills/ws/SKILL.md` (intent detection table + epic/task/done/ship aliases).

## 9. Design-decision flowchart

```
新しい skill を作る
    │
    ▼
副作用がある？ (commit / deploy / send / write)
    ├─ Yes → disable-model-invocation: true
    └─ No
        │
        ▼
    バックグラウンド知識？（参照のみ）
        ├─ Yes → user-invocable: false
        └─ No → デフォルト（双方向）
            │
            ▼
        複雑な推論を含む？
            ├─ Yes → HeavySkill 4-component
            └─ No → 通常テンプレ
                │
                ▼
            tight loop or loose loop？
                ├─ Tight → ユーザー対話・段階確認
                └─ Loose → サブエージェント委任 (context: fork)
```

## 10. Bilingual triggers (EN canonical + Japanese triggers alongside)

A skill's automatic firing depends on matching keywords in the description against natural language.
To make it fire for both Japanese and English users, write the description by the following convention (source: banto-public-release spec T2.1. The Japanese trigger words are already tuned in production, so **preserve them unchanged**):

```yaml
description: |
  <English prose, canonical: what this skill does and when it should fire. 1-3 sentences.>
  Triggers: "research", "investigate", "what's the latest", 「調べて」「最新の〜」「リサーチ」「比較して」
  Do not use when: <exclusions, EN. e.g. searching local context only (use `search`).>
```

Rules:
- **English is canonical for the body** (Claude responds in the user's language even with EN instructions, so the JP user's experience doesn't degrade)
- **List both EN and JP trigger words on the `Triggers:` line**. Move the JP words verbatim from the existing description (do not paraphrase)
- State the exclusion conditions (responsibility boundary) in English too, to prevent misfires
- When there are command aliases (`/xxx`), follow §8 Intent-first to keep "the same place is reachable via natural language"

## Related

- Quality scoring → `references/quality-scoring.md`
- HeavySkill 4-component → `references/heavyskill-template.md`
- All frontmatter fields → `references/skill-md.md`
