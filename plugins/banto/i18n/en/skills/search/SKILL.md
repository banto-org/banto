---
name: search
description: |
  Search the local AI Context (decisions / docs / conversation history) natively with Claude — internal search over information that is already accumulated. Never touches the Web. Expands the query into 3 weighted tiers → scores with the ranking script → Read-verifies the top hits; zero-hit, cross-store, and history queries escalate to a parallel-haiku deep path.
  Triggers: "what did we talk about before", "previous discussion", "past chats", "remember", "recall", "history", "context/backstory", "why did it end up like this", "what did we decide before", "find it". Also invocable via /search <query>.
  Do not use when: fetching new information from external sources (Web / GitHub / arxiv — use the research skill).
user-invocable: true
argument-hint: "[search query]"
allowed-tools: Grep Glob Read Write Edit Bash Agent
compatibility: Claude Code (requires bash, git, jq, python3)
---

# Search — Internal Search (Claude-native)

> **Search base (store-first)**: `{base}` in this skill refers to the ai-context base. Search under the absolute path injected by the SessionStart/PreCompact hooks as 「ai-context ベース: &lt;absolute path&gt;」 (if unknown, resolve with `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`).

If the user converses in Japanese, respond (and write the search report) in Japanese.

## search vs research

| | `/search` (this skill) | `/research` |
|---|---|---|
| Target | **Internal**: `{base}/decisions/` `docs/` + conversation history + `extra_docs_dirs` | **External**: Web, GitHub, arxiv, X, official docs |
| Web access | **None** | Yes (WebSearch + research-agent) |
| Result | References / summaries of existing files | New files saved to `{base}/docs/research/` |
| Latency | fast: seconds / deep: minutes | minutes (parallel research-agent launches) |

**Mnemonic**: do we already have it or not? If we have it → `search`; if we don't → `research`.

## Search targets and data layers

| Path | Contents | Freshness |
|---|---|---|
| `{base}/decisions/` `{base}/docs/` | Design decisions, reports, research | Raw files searched directly |
| `{base}/project-combined.txt` | Concatenated text of the above | Auto-rebuilt on save by hook (ai-context-combined-rebuild.sh) |
| `{base}/full-combined.txt` + `sessions-cache/` | + conversation history (including content lost to compact) | Refreshed on demand at search time (see deep path below) |
| `{base}/search-lexicon.md` | **Search lexicon** (concept ↔ translations / synonyms / abbreviations) | Appended on deep-path success (see below) |
| Project `docs/` `specs/` etc. | Added via `extra_docs_dirs` in `{base}/config.json` | Included in combined generation |

## Search procedure

### Step 0: Read the lexicon

If `{base}/search-lexicon.md` exists, Read it and fold the matching rows' terms into the expansion (skip if absent).

### Step 1: Query expansion (3 tiers, weighted)

Expand the query into **weighted groups** with these rules:

1. **Tier1 (×1.0) = synonyms**: put Japanese synonyms + **English translations** + katakana variants + abbreviations in the same group (always assume records may be in English; 「漂流」→ drift)
2. **Tier2 (×0.6) = near concepts**
3. **Tier3 (×0.3) = adjacent concepts**: words that are "similar but with different intent" go here (監視→監査). Pick them up, but do not let them dominate
4. **Decompose question forms**: "why was X retired" → `[X]` and `[廃止|supersede|撤廃]` as **separate Tier1 groups** (the multi-group match bonus acts as a soft-AND)
5. **Split compound terms**: 「ProjectX 漂流」→ `[ProjectX]` + `[漂流|drift]`
6. Short ASCII tokens (PR/WS/KD) can be passed as-is (the script adds `\b` boundaries)

### Step 2: fast path (default, seconds)

Score with the ranking script:

```bash
python3 "$CLAUDE_PLUGIN_ROOT/scripts/ai_context_search_rank.py" \
  --base "{base}" --top 8 \
  --groups '[[1.0,["認証","auth","OAuth"]],[0.6,["認可"]],[0.3,["ログイン"]]]'
```

- `confident: false` in the output JSON (top score < 1.0) is treated as **zero hits** → go to Step 4
- `confident: true` → go to Step 3

### Step 3: Verification (read and judge)

Read the top 3–5 files and **judge relevance yourself**:

- Exclude polysemy mismatches (e.g. a document where "harness" means wiring)
- Exclude self-references (the document currently being written, evaluation tables that merely quote queries)
- Check supersede relations (has an old decision been overridden by a newer one?)

### Step 4: Second round on zero hits (once only)

Redo Steps 1–2 with a different synonym set (flip the translation direction, expand abbreviations to full names, change the split granularity). Still `confident: false` → escalate to Step 5 deep path.

### Step 5: deep path (parallel haiku, minutes)

**Triggers**: still zero hits after round 2 / "exhaustively", "everything" (「徹底的に」「全部」) / "in other projects" (「他のプロジェクトで」, cross-store) / "what did we talk about before" (「前に話した」, conversation history). History and cross-store queries may skip fast and **start here**.

0. Record the start time (report wall-clock time). For history searches, refresh full-combined first:
   ```bash
   python3 "$CLAUDE_PLUGIN_ROOT/scripts/ai_context_combined.py" --project-root "$PWD" --scope full
   ```
1. Launch **3–5 `search-agent`s (model=haiku) in parallel within one message**. Standard division of labor:
   - (a) Japanese-variant agent: `{base}/decisions/` `{base}/docs/`
   - (b) English / code-term agent: same paths
   - (c) Cross-store agent: `~/ai-context-store/*/decisions/` `*/docs/` (grep the store roots directly)
   - (d) Conversation-history agent: `{base}/full-combined.txt`
2. Always pass to each agent: the regex pattern set / target paths / **limit N (top 15 per pattern, 120-char snippets)** / temp-file output path `{base}/tmp/search/<run-id>-<role>.txt`. Have each agent run its Greps in parallel too
3. **Confidence is judged by candidate agreement across agents** (the same file surfaced by multiple agents is a strong signal; do not use haiku's self-reported confidence)
4. opus (main) Read-verifies the top candidates → synthesizes

### Step 6: Feed back into the lexicon (required on deep success)

When the deep path reaches the right answer, append the expansion that worked to `{base}/search-lexicon.md` as one line:

```markdown
漂流 ↔ drift, W1, Wasserstein   <!-- found via project search -->
```

This makes **the next fast path deterministically smarter the more you search** (shared recall for the team via git).

### Step 7: Report format

```markdown
## Search results: {query}

### Related design decisions
1. **{title}** ({date}, score: X.XX)
   - Decision: {summary}
   - File: {base}/decisions/{filename}

### Related research
- {research file}: {summary}

### Conversation history (when the deep path found matches)
- {summary of matched context}

### Notes
- {supersede relations, explicit "not confident", etc.}

### Search method: {fast (ranking vN) / deep (haiku xN parallel, wall time Xs) / cross-store: {store names,...}}
```

If **not confident** (ended below threshold), do not fill in guesses — state "not confident" explicitly.

## Cross-store NDA / confidentiality

- Keep cross-store search results **as internal references within the session**. Never transcribe another client's specifics (project names, decision contents, people) into the current project's deliverables (code, docs, commits) — the write side is enforced by pii-protection / egress-guard
- Always list which stores were searched in the "Search method" field

## Data-layer maintenance

- `project-combined.txt` is auto-rebuilt by the hook on writes to decisions/docs (ms-scale, no model needed)
- Manual rebuild: `python3 "$CLAUDE_PLUGIN_ROOT/scripts/ai_context_combined.py" --project-root "$PWD" --scope all`
- Temp files under `{base}/tmp/search/` may be deleted once they accumulate
