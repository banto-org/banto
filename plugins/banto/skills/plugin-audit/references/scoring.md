# Quality Evaluation Criteria (14 axes)

The quality-evaluation axes for all banto assets (skill / agent / rule / hook). This document is the **single source of truth** for `plugin-audit`.

**Principle**: do not use surface-level scoring that counts "the number of formulaic words". Raising keyword density degrades boundary-case disambiguation and worsens real precision inversely. Quality is measured by structural validity (static axes) + measured routing eval (Axis 4).

---

## Axis list

| Axis | Content | Type | Owning subcommand |
|------|------|------|-----------------|
| 1 | YAML structural validity (official 19-field coverage + use-case consistency) | static | `plugin-audit` |
| 2 | Body structural validity (500 lines / reference validity / 3-layer progressive loading) | static | `plugin-audit` |
| 3 | description routing format ("Use when..." / negative examples / ≤50 words) | static | `plugin-audit` |
| 4 | Measured precision (Precision / Recall / Forbidden, parallel Agent subs) | dynamic | `plugin-audit eval` |
| 5 | HeavySkill applicability (recommend / unneeded / already adopted / mis-applied / fan-out candidate) | structural judgment | `plugin-audit` |
| 6 | Cross-skill disambiguation matrix (bidirectional references / vocabulary overlap / domain overlap) | static | `plugin-audit` |
| 7 | Generality evaluation (absolute paths / personal names / org names / tool assumptions / [+language/culture/license with global]) | static + dynamic | static → `plugin-audit` / semantic judgment → `plugin-audit eval` |
| 8 | Generalization fitness / rule externalization (dynamically loaded rule, or hardcoded) | static + Agent | `plugin-audit` + `plugin-audit fix` (refactor proposal) |
| 9 | Layer 3 harness-engineering consistency (path-scoping recommendation / hook enforce candidates) | static | `plugin-audit` |
| 10 | ODD (Operational Design Domain) application status (per-skill odd.yaml + autonomy_level validity) | static | `plugin-audit` |
| 11 | Usage (commits + mentions + last update → active/dormant/likely-trim) | static | `plugin-audit-usage.sh` |
| 12 | Permission-scope minimality (**12a** over-grant=minimality / **12b** under-declare=runtime correctness) | static + Agent | `plugin-audit-permissions.sh` → `plugin-audit` |
| 13 | Containment consistency (dangerous commands in hooks / raw secret output) | design | hook target |
| 14 | Content hygiene (specific info / pasted debris: regex layer + semantic layer) | static + Agent | `plugin-audit` always + pre-release gate |

> See SKILL.md (single source) for the subcommand (mode) list + the `global` modifier definition. This document defines the evaluation criteria for each Axis.

---

## Design principle: Reviewer = Fresh Agent

Judgment-type skills (`plugin-audit eval` / `plugin-audit fix` / `harness-audit`) **always judge with a subagent**. The main session has work-history context contamination, which produces self-evaluation bias.

| skill | Reviewer |
|-------|---------|
| `plugin-audit eval` | Agent (general-purpose) judges each case independently, multiple Agents vote |
| `plugin-audit fix` | Agent (general-purpose) proposes fixes, the main session approves interactively |
| `harness-audit` | Delegates subjective axes (dead-feature judgment, etc.) to Agent (general-purpose) |

---

## Axis 1: YAML structural validity

Exhaustively verifies **all 19 official SKILL.md frontmatter fields**.

| Category | Field |
|---------|-----------|
| Identity | `name`, `description`, `when_to_use` |
| Arguments | `argument-hint`, `arguments` |
| Firing control | `disable-model-invocation`, `user-invocable`, `paths` |
| Execution | `allowed-tools`, `model`, `effort`, `context`, `agent`, `shell`, `hooks` |
| Open Standard | `license`, `compatibility`, `metadata` |

### Use-case consistency check (detecting inter-field contradictions)

| Contradiction pattern | Detection condition | Severity |
|------------|---------|-------|
| No way to launch | `disable-model-invocation: true` + `user-invocable: false` | ❌ Critical |
| Natural-language mis-fire risk | skill with side effects (commit / deploy etc.) + `disable-model-invocation: false` | ⚠️ Warn |
| Schema violation | `context: fork` + `agent` unspecified | ❌ Critical |
| Unofficial format | `allowed-tools` comma-separated | ⚠️ Warn (official is space-separated or YAML list) |
| Over-spec | `model: opus` + trivial body (< 30 lines + single function) | ℹ️ Info |
| Subcommand not surfaced | the body documents `` `<skill> <sub>` `` but `argument-hint` omits it | ⚠️ Warn |
| Empty capability claim | an `argument-hint` bareword keyword with no backing in the body | ℹ️ Info (confirm) |

### argument-hint ↔ real-interface fidelity (`plugin-audit-interface.sh`)

The explanation that actually shows when you type the slash command is the `argument-hint`. When it diverges from the skill's real interface, the feature exists but is unreachable. This deterministically enforces CONCEPT's "every command reachable by users who do not know it exists (intent-first)":

- **Not surfaced (⚠ Warn)**: the body documents a subcommand as `` `<skill> <sub>` `` (or `` `/<skill> <sub>` ``) but `argument-hint` does not list it. A user typing `/<skill>` cannot discover it. Examples: plugin-audit's `full`/`eval`/`verify`/`fix`, ws's `switch`/`new`/`multi`/`solo`/`archive`/`import` (both fixed in 5.44.0).
- **Empty claim (ℹ Info, confirm)**: each `argument-hint` segment is exactly a bareword (`init` / `eval` etc.) yet never appears in the body = advertised but not implemented/documented. A positional placeholder (a descriptive segment such as `export-target-dir (defaults to …)`) is not treated as a keyword, so it does not false-flag.

Extraction is static and high-precision (subcommands are anchored to `` `<skill> <word>` `` code spans). The agent pass settles boundary cases.

### description character caps (official spec)

- **Open Standard**: description alone ≤ **1,024 chars**
- **Claude Code**: description + when_to_use combined ≤ **1,536 chars**
- **Dynamic budget**: 1% of context, fallback **8,000 chars** (sum across all skills)

| Status | Condition |
|--------|------|
| OK | description (+ when_to_use) ≤ 1,024 chars |
| ⚠️ Warn | 1,024 < combined ≤ 1,536 |
| ❌ Hard | combined > 1,536 (official combined-cap violation, display cut occurs) |

---

## Axis 2: Body structural validity

| Item | Criterion | Severity |
|------|------|-------|
| 500-line rule | body ≤ 500 lines | ⚠️ Warn if exceeded |
| Token budget | warn=500 token / hard=1000 token (concat: description + body) | recommend `references/` split if exceeded |
| Reference-file validity | the link target of `[ref](references/foo.md)` actually exists | ❌ Critical |
| Internal skill-reference validity | the X written as "X skill" in description / body actually exists | ⚠️ Warn |
| 3-layer progressive-loading structure | a large skill adopts a `references/` split | ℹ️ Info |

### 3-layer progressive loading (Perplexity style)

| Layer | Content | Token guideline |
|---|------|------------|
| Index | description + when_to_use (frontmatter) | ≤ 100 token |
| Load | SKILL.md body | ≤ 5,000 token |
| Runtime | `references/*.md` (Read only when needed) | unlimited |

### Shape-up triggers (`plugin-audit-shapeup.sh` — thresholds are not gates)

Leanness signals that keep the skill set shaped up. **Important: every threshold here is a review trigger, not a gate (pass/fail).** Exceeding it is not ❌ but "review this for slimming". A low threshold does not cause a false failure — the agent reads the content and exonerates it if justified — so they are set **generous (catch-more)**. The `shapeup` subcommand hands each trigger's content to an agent and asks for a concrete slimming proposal (split / extract / rule-ify / consolidate) or a "justified" verdict.

| Trigger | Condition | Rationale |
|---|---|---|
| Bloated body | SKILL.md body > 400 lines | slim before the Axis 2 hard cap of 500 |
| Bloated subtree | whole-skill subtree > 50 KB | catches only the genuinely heavy skills (the rest pass through) |
| Weight concentration | a single skill > 25% of total weight | detects outliers (future runaway guard) |
| Near-duplicate | ≥ 8 consecutive identical substantive lines shared by ≥ 2 skills | copy-paste → extract to a shared reference/rule. 8 lines excludes headers / short boilerplate while catching procedure blocks and shared preambles (measured: a threshold of 5 catches structural lines by coincidence = noise; 8 is clean) |

Dormancy (Axis 11 `dormant` / `likely-trim`) and the assets oversized-reference / orphan / duplicate signals fold into the same review.

---

## Axis 3: description routing format

The description is a **routing trigger that decides whether a Skill should launch**, functioning as a ≤50-word Index-layer token.

### Detection items

| Item | Criterion | Severity |
|------|------|-------|
| "Use when..." form | description begins with "Use when..." or an equivalent expression ("when... / in the case of...") | ℹ️ Info (recommended) |
| **Presence of negative examples** | examples that suppress loading near the boundary are made explicit, such as "do not use when", "out of scope", "suffices", "dedicated" | ⚠️ Warn (most important, the primary signal in the Perplexity official docs) |
| Within 50 words | the description body (excluding when_to_use) is roughly 50 words or fewer | ⚠️ Warn if exceeded |
| Index-layer token over | description + when_to_use combined exceeds 300 token | ⚠️ Warn |

### Anti-patterns

- ❌ Writing "INVOKES: ..." in the description → "what it does" info, should not go in the Index layer
- ❌ Mechanically adding "a simple 1-file... suffices" to every skill → dilutes negative examples, worsens precision
- ❌ Raising keyword density → worsens boundary-case disambiguation

---

## Axis 4: Measured precision (Perplexity style, dynamic via `plugin-audit eval`) — two layers, routing + functional

This axis measures **routing** (does the right skill fire?). The **functional** layer — whether the skill works as claimed once fired — is handled by the `plugin-audit verify` subcommand (`references/verify.md` / per-skill `verify-cases.yaml`), covering routing→execution end-to-end. The routing **model-tier sweep** (haiku/sonnet/opus) is opt-in via `eval --tiers` (below).


Define **positive / negative / boundary** cases (3 kinds) in `eval/skill-routing.yaml` (or `skills/plugin-audit/eval-cases.yaml`), and compute the following 3 metrics with Agent subagents:

| Metric | Definition |
|------|------|
| **Precision** | the proportion where top-1 matched the correct answer (does it avoid mis-firing) |
| **Recall** | the proportion where the correct skill was included in top-K (misses) |
| **Forbidden** | the proportion where non-loading was maintained on "must-not-load" cases |

### Implementation policy

- **Vote each case with multiple Agent subagents** (avoid contamination, reduce bias)
- **Model-tier verification (required when `eval --tiers`)**: measure routing across 3 tiers Opus / Sonnet / Haiku and report per-tier Precision. Flag skills that degrade on cheaper models (banto delegates to haiku by design = degradation is a production risk). Per-tier votes opus V=1 / sonnet V=3 / haiku V=5. Fix the tier with the Agent tool's model pin (proven in search/kit). All tiers only when `--tiers` is explicit; default is a single tier (backward-compatible)
- Case-type ratio: positive 40% / negative 30% / boundary 30%
- **Weight boundary cases most heavily** (precision regressions have been detected here before)

---

## Axis 5: HeavySkill applicability

| Category | Condition | Action |
|---------|------|-----------|
| **Recommend** | Agent in `allowed-tools` + parallelism/comparison/trade-off/branching in the body + Phase 3 or higher | propose adopting the 4-component template |
| **Unneeded** | single function / mechanical procedure / 1-2 tools | do not adopt (keep as is) |
| **Already adopted** | the 4 components are present | display only |
| **Mis-applied** | a simple skill that adopts the 4-component template | propose lightening |
| **Fan-out candidate** (the "auto-distribute without human orchestration" lens) | Agent in `allowed-tools` + the body processes independent items *sequentially* ("run each X in turn", etc.) yet has no Parallel Protocol | propose parallel fan-out (multiple Agents in one message). Excludes sequentially-dependent tasks and single-function skills — the agent filters false positives (ties directly to the north star: humans never think about invocation = self-driving distribution) |

### HeavySkill 4-component detection (all 4 blocks)

1. **Activation Conditions**
2. **Parallel Protocol** / Parallel Reasoning
3. **Deliberation** / Deliberation Prompt
4. **Output Constraints**

Source: https://arxiv.org/abs/2605.02396

Judgment is **delegated to Agent (general-purpose)** (the Reviewer = Fresh Agent principle).

### Existing judgment examples

- (Currently, no skill fully adopts the HeavySkill 4-component template)
- `plugin-dev`: **recommended candidate**
- `plugin-audit`: partial-adoption candidate
- `status`, `save-checkpoint`: **unneeded** (single-function UTILITY)

---

## Axis 6: Cross-skill disambiguation matrix

When the boundary between skills is ambiguous, Claude's routing judgment wobbles.

| Item | Detection method | Severity |
|------|---------|-------|
| Bidirectional reference | whether A's description references B and B's description references A | ℹ️ Info (appropriate) |
| Vocabulary overlap | Jaccard coefficient of trigger-word bigrams in the descriptions | ⚠️ Warn > 0.4 |
| Domain categorizing | classification-tag collision among WORKFLOW / UTILITY / ANALYSIS / META | ⚠️ Warn |
| Boundary ambiguity | Agent (general-purpose) judges "could apply to either" | ⚠️ Warn |

Judgment: mechanical computation + Agent assistance.

---

## Axis 7: Generality evaluation

### Inspection items

| Category | Detection pattern | Type |
|---------|------------|------|
| Absolute-path dependence | `/Users/[name]/`, `C:\Users\` etc. | static (regex) |
| Personal-name dependence | hardcoding a specific GitHub ID / naming convention | static (regex) |
| Org-name dependence | own company name / internal URL / private-repo link | static (regex) |
| Project-specific names | self-references such as "Adrite" / "banto" | static (regex) |
| Language dependence | Japanese-only trigger words / a specific language's regex | static |
| Tool assumptions | Mac-only `open -a` / a specific IDE / a specific package manager | static |
| Business-knowledge dependence | internal rules / contract terms / regulation references | **Agent judgment** |
| License compatibility | proprietary reference targets / links to internal-only docs | **Agent judgment** |

### Branching by the `global` modifier

| Check item | Default | With `global` |
|------------|-----------|----------------|
| Absolute path | ✓ ON | ✓ ON |
| Personal name | ✓ ON | ✓ ON |
| Org name | ✓ ON | ✓ ON |
| Project-specific name | ✓ ON | ✓ ON |
| Tool assumptions (Mac-only etc.) | ⚠️ WARN only | ✓ ERROR |
| **Language dependence (Japanese-only etc.)** | **✗ OFF** | **✓ ON** |
| **Cultural assumptions (Japanese business customs etc.)** | **✗ OFF** | **✓ ON** |
| **License compatibility** | ⚠️ WARN | ✓ ERROR |

### Generality score

- **Generic**: 0 violations, runs in every environment (publishable)
- **Light-locked**: minor dependence (OS-only commands etc.) — warning
- **Locked**: personal name / org name / absolute path mixed in — error, to be fixed
- **Org-internal**: assumes within-org use (recommend explicitly separating as a template)

---

## Axis 8: Generalization fitness / rule externalization

Judge whether **criteria that can vary per company / project / team** — such as "coding conventions", "review criteria", "spec templates" — are **hardcoded inside the skill / dynamically loaded from `.claude/rules/{topic}.md`**.

### Detection pattern

- the skill body describes a **fixed criterion** like "follow the coding conventions in ..." or "review viewpoints are ..."
- and that criterion is not loaded from `.claude/rules/{topic}.md` (reference resolution is single-path)

→ rule-externalization recommendation flag ON

### Representative detected skills

- `spec`: spec template → `.claude/rules/spec-template-link.md`
- `concept`: ideology/North-Star decision axes → `.claude/rules/concept-system.md`
- `knowledge`: knowledge taxonomy → `.claude/rules/knowledge-system.md`
- `ai-context` (sort project): doc-organization criteria → `.claude/rules/doc-system.md`
- `status`: report formatting → `.claude/rules/status-format.md`

> Note: `review` / `audit` are delegated to the official Anthropic plugins.

### Unified refactor pattern (3-stage fallback)

```
[skill-internal logic, unified]

1. Read .claude/rules/{topic}.md (rules placed by harness-setup.sh / the project side)
2. if absent → look under .ai-context/refs/{topic}/:
   2a. use the search skill (query expansion + grep ranking) to find the semantically closest section
   2b. if search finds nothing → Read .ai-context/refs/_index.md → Read section by section
3. if still absent → use the skill's built-in default
```

---

## Axis 9: Layer 3 harness-engineering consistency

### Detection signals (rule side)

| Signal | Meaning | Recommended action |
|---------|------|--------------|
| `rule_should_path_scope = 1` | rule has no `paths:` + body mentions extensions/glob/manifest | add `paths:` frontmatter to switch to conditional injection (avoid the context bloat of always-on injection) |
| `rule_hard_constraint = 1` | rule body has enforcing expressions — "MUST" / "NEVER" / "always" / "forbidden" (or the Japanese 「必ず」「禁止」) | rules are probabilistically obeyed (AGENTIF: tool constraint 43.2%). Where possible, make it deterministic enforce with a PreToolUse hook + `permissions.deny` (AgentSpec: 90-100% blocked) |

### Detection signals (hook side)

| Signal | Meaning | Recommended action |
|---------|------|--------------|
| `hook_event = unregistered` | a script under hooks/ is not registered in hooks.json | delete dead code OR fix the hooks.json registration omission (`_`-prefixed helpers are an exception) |
| `hook_event = PreToolUse` + `hook_blocks = 0` | PreToolUse yet no blocking pattern such as exit 2 | re-decide whether you actually want to stop tool execution or it is for logging (if the latter, consider moving to PostToolUse) |
| Cross-check of the `hook_blocks = 1` hook list with the `rule_hard_constraint = 1` rule list | whether a rule's hard_constraint is deterministically enforced by a hook | a human judges the semantic match — if uncovered, consider adding a hook |

### Output

- **Warning**: list of files recommended for path-scoping (rule)
- **Info**: list of hook-enforce candidate files (rule; convertibility is a human judgment)
- **Hook list**: list of event / matcher / block-or-warn patterns
- **Critical**: hook scripts not registered in hooks.json (dead-code candidates)
- **Warn**: PreToolUse hooks with no blocking pattern (intent unclear)
- **Coverage check**: parallel list of hard_constraint rules × block hooks (starting point for manual review)

### Expected false positives

- when a rule body writes an extension in an **example** (e.g. `*.md` written as an example inside `evidence-first.md`)
- a rule with a "Prohibitions" section heading (conceptual prohibitions unsuited to hook-ification)
- `_`-prefixed helper scripts (deliberately unregistered in hooks.json, for source sharing)

These are recommendations, not enforcement. The final judgment is made by a human.

---

## Axis 10: ODD (Operational Design Domain) application status

### Detection signals (skill-only evaluation)

| Signal | Meaning | Recommended action |
|---------|------|--------------|
| `has_odd_yaml = 0` | the skill directory has no odd.yaml | recommended for L1-L3 skills. For L0 lightweight utilities (search / status etc.), application is optional under the 10-line rule |
| `odd_autonomy_level = L4 / L5` | autonomy_level is outside the banto range | split into a separate plugin (`banto-autonomy`) or reconsider autonomy_level |
| `has_odd_yaml = 1` + `odd_autonomy_level = empty` | odd.yaml exists but autonomy_level extraction failed | check the format (`autonomy_level: L2  # ...` form is required) |

### Output

- **Summary**: ODD application rate + autonomy_level distribution
- **Warning**: list of skills without ODD applied (all, including L0; a human judges the L0 optionality)
- **Critical**: list of skills whose autonomy_level is L4 / L5
- **Info**: list of autonomy_level extraction failures (format errors)

### Expected false positives

- L0 (Manual) skills have a trivial ODD spec (a few lines of in_scope / out_of_scope suffice), so deciding not to apply one is plausible
- transitional skills (before odd.yaml is in place) temporarily show as Warn

These are treated as Warn, not Critical. Only L4/L5 are Critical (plugin-boundary violation).

---

## Axis 11: Usage (`plugin-audit-usage.sh`)

Tally git-log mentions over the past N days (default 30) + mentions inside `.ai-context/{decisions,docs}` + the SKILL.md last-update date, and classify each skill into 4 categories.

| Category | Condition | Action |
|---|---|---|
| `active` | commits ≥ 3, or commits ≥ 1 and mentions ≥ 10 | keep |
| `mentioned` | commits ≥ 1, or mentions ≥ 5 | stable (no watching needed) |
| `dormant` | only mentions ≥ 1 | ⚠ consider merging / deleting |
| `likely-trim` | zero commits, zero mentions | ⚠️ strongly recommend rule-ification / merging / deletion |

Run:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-usage.sh <plugin_dir> [since_days]
${CLAUDE_PLUGIN_ROOT}/scripts/plugin-audit-usage.sh --skill <skill_dir> [since_days]  # per-skill
```

## Axis 12: Permission-scope minimality — 12a over-grant / 12b under-declare (static `permissions` + agent judgment)

Inspect whether `allowed-tools` is **the necessary minimum**. The "make it structurally impossible to execute" principle from the MS Agent Governance Toolkit.

`plugin-audit-permissions.sh` generates static candidates (declared `allowed-tools` vs idiom-based actual usage in body+references) → the Agent finalizes. Scoped grants (`Bash(git:*)`) are matched on the base tool; Agent/Task are treated as the same tool.

| Inspection | Sub-axis | Severity |
|---|---|---|
| a skill with no writes holds `Write` / `Edit` | 12a over-grant | ⚠️ Warn (over-grant) |
| a display-only skill (L0) holds `Bash` / `Agent` | 12a over-grant | ⚠️ Warn |
| no usage idiom for a declared tool anywhere in the body | 12a over-grant | ℹ️ Info (drop candidate) |
| the body uses a tool via idiom but `allowed-tools` is undeclared (runtime block) | **12b under-declare** | 🔴 High (real block at runtime = real harm; heavier than over-grant) |
| `Bash(*)` wildcard grant (when it can be narrowed to specific commands) | 12a over-grant | ℹ️ Info |

The static path generates candidates (prose-noisy Read/Write/Edit are marked with `?`). The final judgment is the Agent (Reviewer = Fresh Agent), resolving prose false positives.

## Axis 13: Containment consistency (agent judgment, hook target)

Inspect the danger level / unsandboxed operations of the commands a hook contains. Equivalent to the environment layer of Anthropic's "How We Contain Claude" 3-layer defense (environment / model / external content).

| Inspection | Severity |
|---|---|
| a hook contains a dangerous pattern such as `rm -rf` / `curl \| sh` / `eval` | ❌ Critical |
| a hook raw-outputs `.env` / a secret (without masking) | ❌ Critical |
| a hook accesses an external network (unexpected curl/wget) | ⚠️ Warn |
| a PreToolUse hook does heavy work with no timeout set | ℹ️ Info |

## Axis 14: Content hygiene (collect column 47 + registry-driven column 34 + assets subtree)

Inspect whether "content that must not live in a document" is mixed into the prose of a skill / agent / rule
(positioned as promoting the one-off pre-release audit into a permanent inspection).

| Inspection | Detection method | Severity |
|---|---|---|
| Specific info (internal member names / client names) | **registry-driven** (OR-join the literals in `~/.claude/banto-name-registry`. no-op = fail-open if the registry is absent. **Never hardcode names in the inspection script**) | ⚠️ Warn (treated as ❌ if a public artifact) |
| Personal absolute path / email | existing Axis 7 (abs_path_count / email_count) | ❌ Locked |
| Pasted run output / session debris | `HYGIENE_RUNLOG_PAT`: `^exit=N` / ✓✗ result lines / "ALL PASS" / subagent_tokens / duration_ms= / tool temp paths (/private/tmp/claude\*, /var/folders/) / datetime with seconds (log lines) | ⚠️ Warn |

- **Handling Warn**: a hit ≠ immediate NG. A deliberate display-format spec (e.g. a skill's "✓ Created..." completion-summary template definition) is legitimate. Run output / task-notification fragments pasted during dogfooding are to be removed. The report enumerates file + hit count, and a human (or a higher audit) decides.

### Subtree extension (`plugin-audit-assets.sh`)

`collect.sh` only emits **SKILL.md** as a row, so `references/*.md` and every nested file escape the hygiene checks above. The more index-shaped a skill is, the more of its content lives in references (e.g. ai-context keeps most of its bulk in 9 reference files), and internal-name / specific-info leaks tend to accumulate in references rather than SKILL.md. `plugin-audit-assets.sh` fills this by walking the whole `skills/*/` subtree:

| Section | Content | Axis | Severity |
|---|---|---|---|
| 1 inventory | files / bytes / lines per skill (heaviest first) — where weight concentrates | Axis 2 | ℹ Info |
| 2 unnecessary files | `.DS_Store` / `Thumbs.db` / `*.bak\|.old\|.tmp\|.orig\|.rej\|.swp` / `*~` / `*.pyc` / `__pycache__` / `*.log` + empty files | Axis 2 | ❌ remove |
| 3 orphan references | basename reachable from neither SKILL.md nor any sibling reference = unreachable dead weight | Axis 2 | ⚠ confirm, then remove/link |
| 4 slimming candidates | references over 500 lines (the Runtime layer is uncapped, but the heaviest are the best split/trim targets) | Axis 2 | ℹ Info |
| 5 duplicate files | identical content by cksum (empty files excluded) → consolidation candidate | Axis 2 | ℹ Info |
| 6 hygiene | applies the 3 patterns above (runlog / absolute path / email / registry name) to **non-SKILL.md files** | Axis 14 | ⚠ Warn |

Patterns are shared from `collect.sh` as the source of truth (the duplication is noted in a header comment). If the registry is absent, the name check is a no-op (fail-open).

### Axis 14 semantic mode (agent review — contamination regex cannot catch)

On top of the static regex, layer a **per-file agent review**
(timing: required at the pre-release gate + during `plugin-audit global`). Pass each skill / agent / template
**plus each skill's `references/` + nested files** (prioritizing the `assets.sh` section-6 hits) to a
subagent and have it judge by the following 3 questions:

| Q | Judgment criterion | Example |
|---|---|---|
| **Q1 Relevance** | does every section serve that skill's declared responsibility (description)? Flag instructions for other skills / paragraphs belonging to no skill / edit-residue contamination | a research procedure written inside the spec skill, etc. |
| **Q2 Generality** | **is it within general knowledge?** References to the product's own design (banto's architecture, store layout, etc.) are legitimate. If **a specific organization's business practices / internal processes / a specific client's business rules** are written "as if general", flag it. Templates are especially strict (only the industry-general form of BRD/spec/norms) | a specific company's approval flow or proprietary contract custom mixed into a template, etc. |
| **Q3 Debris** | pasting that slipped past the regex (conversation fragments / "as a result of ~"-type history descriptions / temporary memos) | "as became clear in the previous session", etc. |

- Output schema: `{file, quote(short quote), type: irrelevant|non-general|debris, severity, suggested_fix}`
- Fixes are review-then-fix (the agent only reports; rewriting is done by a human or higher session after a decision)


---

## References

- Official plugin docs: https://code.claude.com/docs/en/plugins
- Perplexity skill routing: https://research.perplexity.ai/articles/designing-refining-and-maintaining-agent-skills-at-perplexity
- HeavySkill: https://arxiv.org/abs/2605.02396
- Verification data: `skills/plugin-audit/eval-cases.yaml` (routing eval cases)
