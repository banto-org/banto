# Document-generating skills — common pattern (single source of truth)

**Target skills**: `status` / `memo` / `knowledge`
**Purpose**: skeleton for adding new document-generating skills + cognitive map of the existing 3

---

## 1. Common frontmatter skeleton

```yaml
---
name: <skill-name>
description: "<one-line description>. <output destination or agent integration>. Triggers: <natural-language phrases (EN)> / 「<日本語トリガー>」. Also invocable via /<skill-name>."
user-invocable: true
argument-hint: "[argument description (behavior when omitted)]"
model: sonnet                # required only for agent-invoking skills; pure-template skills may omit
allowed-tools: Read Write Glob <plus Agent Grep Bash as needed>
---
```

**Fixed items**:
- `user-invocable: true` and **no** `disable-model-invocation` — the skill is discoverable by natural language (intent-first) *and* invocable via `/cmd`. Never add `disable-model-invocation: true`; it would hide the skill from natural-language discovery (against the intent-first principle)
- The description carries natural-language Triggers (EN + JA) plus a "Do not use when" boundary
- `argument-hint` states the default behavior when omitted, in parentheses

**Variable items**:
- `model`: agent-invoking skills specify sonnet; pure-template skills (memo/status, etc.) omit it and use the plugin default
- `allowed-tools`: agent-invoking skills include `Agent`; add `Bash` only when Bash is used

---

## 1.5. Output language policy (common)

Generated artifacts are written **in the user's conversation language by default** (if the user converses in Japanese → Japanese; in English → English). Fixed conventions stay bilingual-by-design and are **not** translated: prefixes (`[Status]` etc.), file names, command names, and trigger words are preserved as-is. English headings inside templates are **structural placeholders** — translate them into the target language to match the document body.

---

## 1.6. Japanese writing-style rule (apply when the artifact is Japanese AND the rule is enabled)

The writing-ja rule is **opt-in** (toggled via `/set-language`; managed by `writing-ja-toggle.sh`). It is enabled iff `~/.claude/rules/writing-ja.md` exists — when the file is absent the user has opted out: skip this section and write natural Japanese prose. When the generated document is **Japanese** and the file exists, follow it (skills must apply it deliberately, not rely on it being ambient). Run these checks before saving:

- **No だ・である・です・ます at sentence ends** — use 体言止め (noun-ending) or the plain 終止形.
- **Reduce katakana-English** — write plain Japanese where a plain word exists (canonical → 正本, deterministic → 毎回同じ動き, etc.).
- **Half-width space at JA↔alphanumeric boundaries** (e.g. 「Claude を使う」), but not around punctuation.
- **Don't round numbers in reports** — exact figures only (write "32 件", never "約 30").

This applies to the **Japanese artifact body only**; English output follows ordinary prose. The full rule + the post-writing checklist live in `~/.claude/rules/writing-ja.md`.

---

## 2. The two patterns

### Pattern A: agent-invoking (skeleton — currently no doc-generation skill uses it)

```
Step 1: Determine the target (parse $ARGUMENTS, fall back to defaults)
Step 2: Invoke with Agent(subagent_type="<agent>", prompt="...")
Step 3: Write the result to `.ai-context/docs/[<Prefix>] <slug>-<YYYY-MM-DD>.md`
Step 4: Show the user a summary ordered by priority (Critical/High first)
```

> E2E runs via the qa-tester agent (direct launch) and saves with the `[QA]` prefix.
> The `[QA]` / `[Audit]` / `[Review]` prefixes are reserved for manually authored documents (their generator skills are delegated to agents / official Anthropic plugins).

### Pattern B: fill-in template (`status` / `memo` / `knowledge`)

```
Step 1: Determine arguments / mode ($ARGUMENTS present or not, sub-arguments)
Step 2: Collect context (conversation history / tasks.md / git log / decisions/, etc.)
Step 3: Fill the template and Write to `{base}/docs/[<Prefix>] <slug>-<YYYY-MM-DD>.md`
Step 4: Report completion + summary to the user
```

| Skill | Mode branching | Destination |
|---|---|---|
| status | none (auto-generate) / `progress` (display only, no save) / period | `[Status]` |
| memo | none (conversation summary) / args (specified content) | `[Memo]` |
| knowledge | none (list drafts/) / `promote` (promotion) / topic (new) | directly under `knowledges/` + `drafts/` |

---

## 3. Naming rules

### Filename

```
.ai-context/docs/[<Prefix>] <slug>-<YYYY-MM-DD>.md
```

- `<Prefix>` is one of the fixed 8 (`[Review] [QA] [Audit] [Status] [Design] [Guide] [Memo] [Index]`)
- `<slug>` is kebab-cased from `$ARGUMENTS`; when empty, use a default slug such as `session-summary`
- `<YYYY-MM-DD>` is the creation date (local time)
- **Prefix enforcement**: the `ai-context-prefix-check.sh` hook validates on write

### No new prefixes

Never invent prefixes beyond the 8 above. If one is needed, consult the user and update both the list in `ai-context/SKILL.md` and this pattern doc.

### The knowledge exception

Only `knowledge` uses the structure of `knowledges/` directly + a `drafts/` subdirectory. No prefix is attached (for knowledge, the title is the filename).

---

## 4. Common report format

The "user report" in Step 4 keeps this skeleton:

```markdown
## <Document type> created

**Saved to**: `.ai-context/docs/<filename>`

### Summary
- <3-5 key points>

### Recommended actions (if any)
- <what to do next>
```

**Principle**: return "summary + saved path", not a full dump (the user can Read the file; saves tokens).

---

## 5. Adding a new document-generating skill

1. Read this pattern doc and decide whether it fits Pattern A or B
2. Bootstrap `skills/<new-skill>/SKILL.md` from the frontmatter skeleton
3. Write Steps 1-4 following the skeleton
4. If a new prefix is needed, add it to the list in `ai-context/SKILL.md` (it also propagates to the hook's enforcement list)
5. Add one line to "document-creation skills" in `kit/SKILL.md`
6. Add one line to the command list in `README.md`
