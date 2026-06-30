# Quality evaluation criteria (15 axes)

Quality evaluation axes for every Banto asset (skill / agent / rule / hook). This document is the **single source of truth** for `plugin-audit`.

**Principle**: Don't use surface-level scoring that counts "the number of formulaic words." Pushing keyword density up degrades disambiguation on boundary cases and worsens real precision in inverse proportion. Quality is measured by structural validity (static axes) plus a real routing eval (Axis 4).

---

## Axis overview

| Axis | Content | Type | Owning subcommand |
|------|------|------|-----------------|
| 1 | YAML structural validity (full coverage of the official 19 fields + use-case consistency) | Static | `plugin-audit` |
| 2 | Body structural validity (500-line / reference validity / 3-tier progressive loading) | Static | `plugin-audit` |
| 3 | description routing form ("Use when..." / negative examples / ≤50 words) | Static | `plugin-audit` |
| 4 | Real-precision measurement (Precision / Recall / Forbidden, via parallel Agent subs) | Dynamic | `plugin-audit eval` |
| 5 | HeavySkill applicability (recommended / unnecessary / already adopted / misapplied / fan-out candidate) | Structural judgment | `plugin-audit` |
| 6 | Cross-skill disambiguation matrix (bidirectional references / vocabulary overlap / domain overlap) | Static | `plugin-audit` |
| 7 | Generality evaluation (absolute paths / personal names / org names / tool assumptions / [+language/culture/license under global]) | Static + dynamic | static → `plugin-audit` / semantic → `plugin-audit eval` |
| 8 | Generalization fitness / rule externalization (whether a rule is loaded dynamically or hardcoded) | Static + Agent | `plugin-audit` + `plugin-audit fix` (refactor proposal) |
| 9 | Layer 3 harness-engineering consistency (path-scoping recommendations / hook enforce candidates) | Static | `plugin-audit` |
| 10 | ODD (Operational Design Domain) application status (per-skill odd.yaml + autonomy_level validity) | Static | `plugin-audit` |
| 11 | Usage (commits + mentions + last update → active/dormant/likely-trim) | Static | `plugin-audit-usage.sh` |
| 12 | Permission-scope minimality (**12a** over-grant = minimality / **12b** under-declaration = runtime legitimacy) | Static + Agent | `plugin-audit-permissions.sh` → `plugin-audit` |
| 13 | Containment consistency (dangerous commands in hooks / raw secret output) | Design | hook target |
| 14 | Content hygiene (proprietary info, paste-in debris: regex layer + semantic layer) | Static + Agent | `plugin-audit` always + pre-publish gate |

> See SKILL.md (the single source) for the list of subcommands (modes) and the definition of the `global` modifier. This document defines the evaluation criteria for each Axis.

---

## Design principle: Reviewer = Fresh Agent

The judgment-type skills (`plugin-audit eval` / `plugin-audit fix` / `harness-audit`) **must always render their judgment in a subagent**. The main session carries work-history context contamination, which produces self-evaluation bias.

| skill | Reviewer |
|-------|---------|
| `plugin-audit eval` | Judge each case independently with an Agent (general-purpose); vote across multiple Agents |
| `plugin-audit fix` | An Agent (general-purpose) proposes fixes; interactive approval happens in the main session |
| `harness-audit` | Delegate subjective axes such as dead-skill judgment to an Agent (general-purpose) |

---

## Axis 1: YAML structural validity

Exhaustively verify **all 19 fields** of the official SKILL.md frontmatter.

| Category | Fields |
|---------|-----------|
| Identity | `name`, `description`, `when_to_use` |
| Arguments | `argument-hint`, `arguments` |
| Trigger control | `disable-model-invocation`, `user-invocable`, `paths` |
| Execution | `allowed-tools`, `model`, `effort`, `context`, `agent`, `shell`, `hooks` |
| Open Standard | `license`, `compatibility`, `metadata` |

### Use-case consistency check (detecting inter-field contradictions)

| Contradiction pattern | Detection condition | Severity |
|------------|---------|-------|
| No way to invoke | `disable-model-invocation: true` + `user-invocable: false` | ❌ Critical |
| Natural-language misfire risk | Side-effecting skill (commit / deploy etc.) + `disable-model-invocation: false` | ⚠️ Warn |
| Schema violation | `context: fork` + `agent` unspecified | ❌ Critical |
| Non-official format | `allowed-tools` comma-separated | ⚠️ Warn (official is space-separated or a YAML list) |
| Over-spec | `model: opus` + trivial body (< 30 lines + single feature) | ℹ️ Info |
| Subcommand not surfaced | A subcommand the body documents as `` `<skill> <sub>` `` is missing from `argument-hint` | ⚠️ Warn |
| Empty feature declaration | A bareword keyword in `argument-hint` has no backing in the body | ℹ️ Info (confirm) |

### argument-hint ↔ real interface consistency (`plugin-audit-interface.sh`)

The description shown when you type a slash command = `argument-hint`. When this diverges from the skill's real interface, the feature exists but cannot be reached. This deterministically upholds CONCEPT's "commands must be reachable even by users who don't know they exist (intent-first)":

- **Not surfaced (⚠ Warn)**: the body documents a subcommand as `` `<skill> <sub>` `` (or `` `/<skill> <sub>` ``), yet `argument-hint` doesn't list it. A user who types `/<skill>` can't tell it exists. Examples: plugin-audit's `full`/`eval`/`verify`/`fix`, ws's `switch`/`new`/`multi`/`solo`/`archive`/`import` (all fixed in 5.44.0).
- **Empty declaration (ℹ Info, confirm)**: a segment of `argument-hint` is strictly a bareword (`init` / `eval` etc.) yet never appears in the body = advertised but neither implemented nor documented. Positional-argument placeholders (segments with explanatory text such as `export-target-dir (defaults to …)`) are not treated as keywords and don't trigger a false positive.

Extraction is static and high-precision (the subcommand anchor is limited to the `` `<skill> <word>` `` code span). Boundary cases are settled by the agent path.

### description character-count cap (official spec)

- **Open Standard**: description alone ≤ **1,024 chars**
- **Claude Code**: description + when_to_use combined ≤ **1,536 chars**
- **Dynamic budget**: 1% of context, fallback **8,000 chars** (summed over all skills)

| Status | Condition |
|--------|------|
| OK | description (+ when_to_use) ≤ 1,024 chars |
| ⚠️ Warn | 1,024 < combined ≤ 1,536 |
| ❌ Hard | combined > 1,536 (violates the official combined cap; display gets truncated) |

---

## Axis 2: Body structural validity

| Item | Criterion | Severity |
|------|------|-------|
| 500-line rule | body ≤ 500 lines | ⚠️ Warn on overage |
| Token budget | warn=500 token / hard=1000 token (concat: description + body) | recommend splitting into `references/` on overage |
| Reference-file validity | the target of `[ref](references/foo.md)` exists | ❌ Critical |
| Internal skill-reference validity | "X skill" written in the description / body actually exists as X | ⚠️ Warn |
| 3-tier progressive loading structure | a large skill adopts a `references/` split | ℹ️ Info |

### 3-tier progressive loading (Perplexity style)

| Tier | Content | Token guideline |
|---|------|------------|
| Index | description + when_to_use (frontmatter) | ≤ 100 token |
| Load | SKILL.md body | ≤ 5,000 token |
| Runtime | `references/*.md` (Read only when needed) | unlimited |

### Shape-up triggers (`plugin-audit-shapeup.sh` — thresholds are not a gate)

Lightweight signals that keep the skill set tightening. **Important: every threshold here is a "review trigger," not a gate (pass/fail)**. Exceeding one is not ❌ but "shape-up review here." Lowering a threshold won't wrongly fail anything — the agent looks at the content and just excludes it if legitimate — so set them **fairly wide (lean toward over-catching)**. The `shapeup` subcommand hands each trigger's content to the agent and has it return a concrete lightening proposal (split / extract / rule-ify / merge) or "legitimate."

| Trigger | Condition | Rationale |
|---|---|---|
| Body bloat | SKILL.md body > 400 lines | trim before Axis 2's hard 500 |
| Subtree bloat | skill subtree total > 50 KB | catch only the genuinely heavy ones (the rest pass through) |
| Weight concentration | a single skill is > 25% of total weight | detect outliers (a future runaway guard) |
| Near-duplication | a run of ≥ 8 substantive lines is identical in two or more skills | copy-paste → extract into a shared reference/rule. 8 lines is the lower bound that excludes headings and short boilerplate while catching procedure blocks and shared preamble (at threshold 5 structural lines coincide by chance and add noise; 8 is empirically clean) |

Dead skills (Axis 11's `dormant` / `likely-trim`) and the assets' huge references / orphans / duplicates are folded into the same review.

---

## Axis 3: description routing form

The description is the **routing trigger that decides whether a Skill loads**, and it functions as a ≤50-word Index-tier token.

### Detection items

| Item | Criterion | Severity |
|------|------|-------|
| "Use when..." form | the description opens with "Use when..." or an equivalent ("when... / in the case of...") | ℹ️ Info (recommended) |
| **Presence of negative examples** | explicit load-suppression examples near the boundary, such as "when not to use it," "out of scope," "is enough," "dedicated to" | ⚠️ Warn (most important; Perplexity's official primary signal) |
| Within 50 words | the description proper (excluding when_to_use) is roughly 50 words or fewer | ⚠️ Warn on overage |
| Index-tier token overage | description + when_to_use combined exceeds 300 token | ⚠️ Warn |

### Anti-patterns

- ❌ Writing "INVOKES: ..." in the description → that's "what it does" information and shouldn't go in the Index tier
- ❌ Mechanically adding "a simple single-file... is enough" to every skill → dilutes negative examples and worsens precision
- ❌ Raising keyword density → worsens disambiguation on boundary cases

---

## Axis 4: Real-precision measurement (Perplexity style, dynamic via `plugin-audit eval`) — two layers: routing + functional

This axis measures **routing** (does the correct skill fire). The **functional** layer — does the skill actually work as claimed once it fires — is owned by the `plugin-audit verify` subcommand (`references/verify.md`, per-skill `verify-cases.yaml`), covering routing→execution end to end. The routing **model-tier sweep** (haiku/sonnet/opus) is opt-in via `eval --tiers` (below).


Define **positive / negative / boundary** cases in `eval/skill-routing.yaml` (or `skills/plugin-audit/eval-cases.yaml`) and compute the following three metrics in Agent subagents:

| Metric | Definition |
|------|------|
| **Precision** | fraction of cases where top-1 matched the correct answer (does it avoid misfiring) |
| **Recall** | fraction of cases where the correct skill was in the top-K (misses) |
| **Forbidden** | fraction of "must-not-load" cases that stayed non-loaded |

### Implementation approach

- **Vote each case across multiple Agent subagents** (avoid contamination, reduce bias)
- **Model-tier verification (required when `eval --tiers`)**: measure routing across the 3 tiers Opus / Sonnet / Haiku and report per-tier Precision. Flag skills that degrade on cheaper models (Banto's design delegates to haiku = degradation is a production risk). Per-tier votes: opus V=1 / sonnet V=3 / haiku V=5. Pin the tier with the Agent tool's model pin (proven in search/kit). Sweep all tiers only when `--tiers` is given; the default is a single tier (backward compatible)
- Case-type ratio: positive 40% / negative 30% / boundary 30%
- **Treat boundary cases as the most important** (precision regressions have been caught here before)

---

## Axis 5: HeavySkill applicability

| Category | Condition | Action |
|---------|------|-----------|
| **Recommended** | Agent in `allowed-tools` + body has parallelism/comparison/trade-offs/branching + Phase 3 or above | propose adopting the 4-component template |
| **Unnecessary** | single feature / mechanical procedure / 1–2 tools | don't adopt (status quo) |
| **Already adopted** | all 4 components present | display only |
| **Misapplied** | a simple skill that adopted the 4 components | propose lightening |
| **Fan-out candidate** (from the "auto-distribute without a human directing it" angle) | Agent in `allowed-tools` + body processes multiple independent items *sequentially* ("run each X in turn" etc.) yet has no Parallel Protocol | propose parallel fan-out (multiple Agents in a single message). Sequentially-dependent tasks and single-feature skills are out of scope — the agent excludes false positives (humans don't think about invocation = directly tied to the self-driving-distribution north star) |

### HeavySkill 4-component detection (all 4 blocks)

1. **Activation Conditions**
2. **Parallel Protocol** / Parallel Reasoning
3. **Deliberation** / Deliberation Prompt
4. **Output Constraints**

Source: https://arxiv.org/abs/2605.02396

The judgment is **delegated to an Agent (general-purpose)** (Reviewer = Fresh Agent principle).

### Existing judgment examples

- (Currently, no skill fully adopts the HeavySkill 4 components)
- `plugin-dev`: **recommended candidate**
- `plugin-audit`: partial-adoption candidate
- `status`, `save-checkpoint`: **unnecessary** (single-feature UTILITY)

---

## Axis 6: Cross-skill disambiguation matrix

When the boundary between skills is fuzzy, Claude's routing judgment wavers.

| Item | Detection method | Severity |
|------|---------|-------|
| Bidirectional reference | does A's description reference B and B's description reference A | ℹ️ Info (appropriate) |
| Vocabulary overlap | Jaccard coefficient of trigger-word bigrams across descriptions | ⚠️ Warn > 0.4 |
| Domain categorization | clash of WORKFLOW / UTILITY / ANALYSIS / META classification tags | ⚠️ Warn |
| Boundary ambiguity | an Agent (general-purpose) judges "could apply to either" | ⚠️ Warn |

Judgment: mechanical computation + Agent assistance.

---

## Axis 7: Generality evaluation

### Inspection items

| Category | Detection pattern | Type |
|---------|------------|------|
| Absolute-path dependence | `/Users/[name]/`, `C:\Users\` etc. | static (regex) |
| Personal-name dependence | hardcoded specific GitHub IDs / naming conventions | static (regex) |
| Org-name dependence | own company name / internal URLs / private-repo links | static (regex) |
| Project-specific names | self-references like "Adrite" or "banto" | static (regex) |
| Language dependence | Japanese-only trigger words / language-specific regex | static |
| Tool assumptions | Mac-only `open -a` / a specific IDE / a specific package manager | static |
| Business-knowledge dependence | internal rules / contract terms / regulation references | **Agent judgment** |
| License compatibility | references to proprietary targets / links to internal-only docs | **Agent judgment** |

### Branching by the `global` modifier

| Check item | Default | With `global` |
|------------|-----------|----------------|
| Absolute paths | ✓ ON | ✓ ON |
| Personal names | ✓ ON | ✓ ON |
| Org names | ✓ ON | ✓ ON |
| Project-specific names | ✓ ON | ✓ ON |
| Tool assumptions (Mac-only etc.) | ⚠️ WARN only | ✓ ERROR |
| **Language dependence (Japanese-only etc.)** | **✗ OFF** | **✓ ON** |
| **Cultural assumptions (Japanese business customs etc.)** | **✗ OFF** | **✓ ON** |
| **License compatibility** | ⚠️ WARN | ✓ ERROR |

### Generality score

- **Generic**: 0 violations, works in every environment (publishable)
- **Light-locked**: minor dependence (OS-specific commands etc.) — warning
- **Locked**: personal names / org names / absolute paths present — error, needs fixing
- **Org-internal**: assumes internal use (recommend explicitly separating it out as a template)

---

## Axis 8: Generalization fitness / rule externalization

Judges whether standards that **can vary per company / project / team** — "coding conventions," "review criteria," "spec templates," and the like — are **hardcoded inside the skill or loaded dynamically from `.claude/rules/{topic}.md`**.

### Detection patterns

- the skill body describes a **fixed standard** such as "follow ... for coding conventions" or "review lens is ..."
- and that standard is not loaded from `.claude/rules/{topic}.md` (reference resolution is a single path)

→ rule-externalization-recommended flag ON

### Representative skills detected

- `spec`: spec template → `.claude/rules/spec-template-link.md`
- `concept`: ideology / north-star judgment axis → `.claude/rules/concept-system.md`
- `knowledge`: knowledge taxonomy → `.claude/rules/knowledge-system.md`
- `ai-context` (sort project): document-organization criteria → `.claude/rules/doc-system.md`
- `status`: report format → `.claude/rules/status-format.md`

> Note: `review` / `audit` are delegated to Anthropic's official plugin.

### Unified refactor pattern (3-stage fallback)

```
[logic inside the skill, unified]

1. Read .claude/rules/{topic}.md (a rule placed by harness-setup.sh / the project side)
2. If absent → look under {base}/refs/{topic}/:
   2a. use the search skill (query expansion + grep ranking) to find the semantically closest section
   2b. if search finds nothing → Read {base}/refs/_index.md → Read section by section
3. If absent → use the skill's built-in default
```

---

## Axis 9: Layer 3 harness-engineering consistency

### Detection signals (rule side)

| Signal | Meaning | Recommended action |
|---------|------|--------------|
| `rule_should_path_scope = 1` | rule has no `paths:` + the body mentions an extension/glob/manifest | add `paths:` frontmatter to switch to conditional injection (avoid always-on context bloat) |
| `rule_hard_constraint = 1` | the rule body has forcing language like "必ず" / "禁止" / "MUST" / "NEVER" | rules are followed only probabilistically (AGENTIF: tool constraint 43.2%). Where possible, make it deterministic enforcement via a PreToolUse hook + `permissions.deny` (AgentSpec: 90–100% blocked) |

### Detection signals (hook side)

| Signal | Meaning | Recommended action |
|---------|------|--------------|
| `hook_event = unregistered` | a script under hooks/ is not registered in hooks.json | delete the dead code OR fix the missing hooks.json registration (`_`-prefixed helpers are an exception) |
| `hook_event = PreToolUse` + `hook_blocks = 0` | a PreToolUse hook with no blocking pattern such as exit 2 | re-decide whether you actually want to stop tool execution or whether it's for logging (if the latter, consider moving it to PostToolUse) |
| cross-check the list of `hook_blocks = 1` hooks against the list of `rule_hard_constraint = 1` rules | whether the rules' hard_constraints are deterministically enforced by a hook | a human judges the semantic match — if anything is uncovered, consider adding a hook |

### Output

- **Warning**: list of files recommended for path-scoping (rules)
- **Info**: list of hook-enforce candidate files (rules; convertibility is a human call)
- **Hook list**: list of event / matcher / block-or-warn patterns
- **Critical**: hook scripts not registered in hooks.json (dead-code candidates)
- **Warn**: PreToolUse hooks with no blocking pattern (unclear intent)
- **Coverage check**: parallel list of hard_constraint rules × block hooks (a starting point for manual review)

### Expected false positives

- a rule body writing an extension as an **example** (e.g. `evidence-first.md` writing `*.md` as an example)
- a rule that has a "Forbidden" section heading (a conceptual prohibition unsuited to hookification)
- a `_`-prefixed helper script (intentionally unregistered in hooks.json, for source sharing)

These are recommendations, not enforcement. The final call is a human's.

---

## Axis 10: ODD (Operational Design Domain) application status

### Detection signals (skills only)

| Signal | Meaning | Recommended action |
|---------|------|--------------|
| `has_odd_yaml = 0` | the skill directory has no odd.yaml | recommended for L1–L3 skills. For L0 lightweight utilities (search / status etc.), application is optional under the 10-line rule |
| `odd_autonomy_level = L4 / L5` | autonomy_level is outside Banto's range | split it into a separate plugin (`banto-autonomy`) or reconsider the autonomy_level |
| `has_odd_yaml = 1` + `odd_autonomy_level = empty` | odd.yaml exists but autonomy_level extraction failed | check the format (`autonomy_level: L2  # ...` form required) |

### Output

- **Summary**: ODD adoption rate + autonomy_level distribution
- **Warning**: list of skills without ODD (all, including L0; a human judges the L0 optionality)
- **Critical**: list of skills whose autonomy_level is L4 / L5
- **Info**: list of autonomy_level extraction failures (format errors)

### schema lint (`plugin-audit-odd.sh` — deterministic)

Beyond presence / autonomy extraction, validate the **structural validity of odd.yaml** against `templates/odd/odd.schema.yaml`. When a parallel session's revert or paste-back decays an odd into the pre-schema shape (a `domain:` wrapper, a stray `human_oversight`, an `.ai-context/` path, etc.), a visual diff misses it, so reject it deterministically at CI / SessionStart:

| Inspection | Severity |
|---|---|
| missing required key (`schema_version` / `skill` / `autonomy_level` / `in_scope` / `out_of_scope`) | ❌ FAIL |
| unknown key (schema `additionalProperties:false`; e.g. `domain` / `guardrails` / `human_oversight`) | ❌ FAIL |
| `autonomy_level` is L4/L5 (outside Banto's range) or non-Lx | ❌ FAIL |
| `skill:` value mismatches the directory name | ❌ FAIL |
| `schema_version` ≠ 1 / `in_scope` is empty | ❌ FAIL |

`--strict` exits 1 on violation. Cross-skill drift in path spelling (`{base}` / `<base>` / `.ai-context`) is owned by Axis 15 (`plugin-audit-consistency.sh`) (division of labor).

### Expected false positives

- For L0 (Manual) skills, the ODD spec is trivial (a few lines of in_scope / out_of_scope), so deciding not to apply it is reasonable
- A transitional skill (before its odd.yaml is set up) is temporarily shown as Warn

Treat these as Warn, not Critical. Only L4/L5 are Critical (plugin-boundary violations).

---

## Axis 11: Usage (`plugin-audit-usage.sh`)

Aggregate git-log mentions over the past N days (default 30) + mentions inside `{base}/{decisions,docs}` + the SKILL.md last-update date, and classify each skill into 4 buckets.

| Category | Condition | Action |
|---|---|---|
| `active` | commits ≥ 3, or commits ≥ 1 and mentions ≥ 10 | keep |
| `mentioned` | commits ≥ 1, or mentions ≥ 5 | stable (no watch needed) |
| `dormant` | mentions ≥ 1 only | ⚠ consider merging / deleting |
| `likely-trim` | zero commits, zero mentions | ⚠️ strongly recommend rule-ifying / merging / deleting |

Run:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-usage.sh <plugin_dir> [since_days]
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-usage.sh --skill <skill_dir> [since_days]  # per-skill
```

## Axis 12: Permission-scope minimality — 12a over-grant / 12b under-declaration (static `permissions` + agent judgment)

Inspect whether `allowed-tools` is **minimally necessary**. From the MS Agent Governance Toolkit principle of "making it structurally impossible to do."

`plugin-audit-permissions.sh` generates static candidates (declared `allowed-tools` vs idiom-based actual usage across the body + references) → an Agent finalizes. Scoped grants (`Bash(git:*)`) are matched against the base tool; Agent/Task are treated as the same tool.

| Inspection | Sub-axis | Severity |
|---|---|---|
| a non-writing skill holds `Write` / `Edit` | 12a over-grant | ⚠️ Warn (excessive grant) |
| a display-only skill (L0) holds `Bash` / `Agent` | 12a over-grant | ⚠️ Warn |
| a declared tool's usage idiom is nowhere in the body | 12a over-grant | ℹ️ Info (drop candidate) |
| the body uses a tool idiomatically but `allowed-tools` doesn't declare it (runtime block) | **12b under-declare** | 🔴 High (a real block at runtime = real harm; heavier than over-grant) |
| a `Bash(*)` wildcard grant (when it could be narrowed to specific commands) | 12a over-grant | ℹ️ Info |

The static path generates candidates (prose-noisy Read/Write/Edit get a `?`). The Agent (Reviewer = Fresh Agent) finalizes, resolving prose false positives.

## Axis 13: Containment consistency (agent judgment, hook target)

Inspect the danger level and unsandboxed operations of the commands a hook contains. Equivalent to the environment layer of Anthropic's "How We Contain Claude" 3-layer defense (environment / model / external content).

| Inspection | Severity |
|---|---|
| a hook contains a dangerous pattern like `rm -rf` / `curl \| sh` / `eval` | ❌ Critical |
| a hook outputs `.env` / secrets raw (unmasked) | ❌ Critical |
| a hook accesses an external network (unexpected curl/wget) | ⚠️ Warn |
| a PreToolUse hook runs heavy work with no timeout set | ℹ️ Info |

## Axis 14: Content hygiene (collect's 47 lines + registry-driven 34 lines + the assets subtree)

Inspect whether "content that shouldn't live in documentation" has crept into the prose of skills / agents / rules
(a one-off pre-publish audit promoted to a standing inspection).

| Inspection | Detection method | Severity |
|---|---|---|
| Proprietary info (internal member names, client names) | **registry-driven** (OR-join the literals in `~/.claude/banto-name-registry`. No registry → no-op = fail-open. **Don't hardcode names in the inspection script**) | ⚠️ Warn (treated as ❌ if it's a published artifact) |
| Personal absolute paths / email | existing Axis 7 (abs_path_count / email_count) | ❌ Locked |
| Pasted-in run output / session debris | `HYGIENE_RUNLOG_PAT`: `^exit=N` / ✓✗ result lines / "ALL PASS" / subagent_tokens / duration_ms= / tool temp paths (/private/tmp/claude\*, /var/folders/) / datetimes with seconds (log lines) | ⚠️ Warn |

- **Handling Warn**: a hit is not an immediate fail. An intentional display-format spec (e.g. a template definition for some skill's "✓ Created..." completion summary) is legitimate. Run output and task-notification fragments pasted in during dogfooding should be removed. The report lists files + hit counts, and a human (or a higher-level audit) decides.

### Subtree extension (`plugin-audit-assets.sh`)

`collect.sh` picks up **only SKILL.md** as lines, so `references/*.md` and every nested file slip past the hygiene inspection above. The more index-like a skill is, the more its substance lives in references (e.g. for ai-context, most of the body lives in the 9 references), and proprietary / internal-name leaks actually accumulate in references more easily. `plugin-audit-assets.sh` fills this in by scanning the entire `skills/*/` subtree:

| Section | Content | Axis | Severity |
|---|---|---|---|
| 1 Inventory | per-skill files / bytes / lines (heaviest first) — where weight concentrates | Axis 2 | ℹ Info |
| 2 Junk files | `.DS_Store` / `Thumbs.db` / `*.bak\|.old\|.tmp\|.orig\|.rej\|.swp` / `*~` / `*.pyc` / `__pycache__` / `*.log` + empty files | Axis 2 | ❌ remove |
| 3 Orphan references | a basename referenced by neither SKILL.md nor a sibling reference = unreachable dead weight | Axis 2 | ⚠ remove/link after confirming |
| 3b Dangling references | a file anywhere in the subtree points at a `references/X.md` that has no actual file (markdown link / code span / prose; the reverse of orphan; cross-references `skills/<other>/...` and placeholder names are excluded) | Axis 2 | ❌ broken pointer — fix/remove |
| 4 Lightening candidates | references over 500 lines (the Runtime tier is unlimited, but heaviest-first they're prime split/trim targets) | Axis 2 | ℹ Info |
| 5 Duplicate files | matching cksum = identical content (0-byte excluded) → consolidation candidates | Axis 2 | ℹ Info |
| 6 hygiene | apply the 3 patterns above (runlog / absolute path / email / registry names) to **non-SKILL.md files** too | Axis 14 | ⚠ Warn |

Patterns are shared with `collect.sh` as the source of truth (duplicated definitions are flagged in a header comment). No registry → the name check is a no-op (fail-open).

### Axis 14 semantic mode (agent review — leaks that regex doesn't catch)

On top of the static regex, layer a **per-file agent review**
(timing: required at the pre-publish gate + during `plugin-audit global`). Hand each skill / agent / template
**and each skill's `references/` + nested files** (with the `assets.sh` section-6 hits as priority input) to a
subagent, and have it judge against these 3 questions:

| Question | Criterion | Example |
|---|---|---|
| **Q1 Relevance** | does every section serve the skill's declared responsibility (description)? Flag instructions for another skill, paragraphs belonging to no skill, or edit debris | the spec skill containing research's procedure, etc. |
| **Q2 Generality** | **is it within general knowledge?** References to the product's own design (banto's architecture, store layout, etc.) are legitimate. Flag **a specific organization's business practices / internal processes / a specific client's business rules** written "as if they were general truths." Templates are especially strict (only the industry-general form of BRD/spec/norms) | a template carrying a specific company's approval flow or proprietary contract custom, etc. |
| **Q3 Debris** | paste-ins that slipped past the regex (conversation fragments / "as a result of ..."-style narrative / temporary memos) | "as we found in the previous session," etc. |

- Output schema: `{file, quote (short quotation), type: irrelevant|non-general|debris, severity, suggested_fix}`
- Fixes are review-then-fix (the agent only reports; a human or a higher-level session performs the rewrite after judging)


---

## Axis 15: Cross-skill reference consistency / correlation (`plugin-audit-consistency.sh`)

**Question**: do all skills reference "the same place" with **the same spelling**? Whereas store-map-lint detects "wrong paths" by comparing against a manifest (`store-layout.json`), this axis **surfaces, without a manifest**, the "divergence where the same store subpath is spelled with multiple prefixes" via clustering.

Inspections (`plugin-audit-consistency.sh <plugin_dir>`):
- **Check 1 (spelling mismatch)**: extract `(\{base\}|\{BASE\}|<base>|.ai-context)/<subpath>` from every `*.md` / `odd.yaml`. If the same `<subpath>` is spelled with two or more prefixes, report it as divergence with file:line (e.g. `docs/research` referenced via both `{base}` and `{BASE}`).
- **Check 2 (prefix distribution)**: tally each prefix's occurrences. The canonical one is `{base}`. `{BASE}` / `<base>` / `.ai-context` (non-legacy lines) are presented as non-canonical with counts.
- **Check 3 (naming format)**: flag if multiple date formats coexist across decisions / checkpoint / research (decisions' `YYYY-MM-DD` ↔ `YYYY-MM-DD-HHMMSS` coexistence is treated as info under the grandfather spec — no correction needed).

Judgment:
- A spelling mismatch / non-legacy naming mismatch leans Critical (a source of declaration rot that multiplies via reverts and copy-paste). Propose canonicalizing to `{base}`.
- Legacy-contrast lines ("legacy is...", "formerly") and the bare-path scan-exclusion list (`.ai-context/sessions,` etc.) are already excluded as intentional (no false positives).
- Runs always in the default audit (static path). `--strict` exits 1 on divergence.

> Related: store **structural** consistency (folder ↔ skill ↔ actual) is owned by store-map-lint (harness-audit Axis 3), while **spelling** consistency across skills is owned by this axis. Together they close off "declaration rot" from two sides.

## References

- Official plugin docs: https://code.claude.com/docs/en/plugins
- Perplexity skill routing: https://research.perplexity.ai/articles/designing-refining-and-maintaining-agent-skills-at-perplexity
- HeavySkill: https://arxiv.org/abs/2605.02396
- Verification data: `skills/plugin-audit/eval-cases.yaml` (routing eval cases)
