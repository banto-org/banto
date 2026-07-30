# templates/ — Distribution templates and shared assets

Everything under this directory is consumed by a script, hook, skill, or agent — nothing here is
decorative. When adding a file, wire it to a consumer in the same change; when removing a consumer,
remove (or re-home) its template.

## Directory map

| Path | Consumed by |
|---|---|
| `rules/` | `scripts/harness-setup.sh` deploys these behavioral rules to `~/.claude/rules/`; `scripts/export-agents-md.sh` compiles them into a host-agnostic AGENTS.md. JA canonical, EN generated via `i18n/` (exception: `writing-ja.md` is JA-only by nature) |
| `ja-style-core.md` | Compact Japanese style block appended to fan-out agent prompts (the `quality` rule prescribes it; banto's own agents embed it) |
| `workspace-rule.md` | Workspace rule installed per project (`ws` skill; also i18n-managed) |
| `docs/_common-pattern.md` | Shared invocation pattern for document-producing skills (`kit` / `plugin-dev` / `status` skills; `hooks/ai-context-prefix-check.sh`) |
| `model-policy.json` | Operational model defaults — `summarize` (idle-checkpoint background fork: `checkpoint-autofire.sh`, `idle-checkpoint-watch.sh`) and `verify_external` (`scripts/cross-check.sh`). Fan-out model selection is delegated to the main AI (no prescriptive roles; `quality` rule prescribes only granularity and parallelism) |
| `odd/odd.schema.yaml` | Schema for each skill's `odd.yaml` (`plugin-audit-odd.sh`; referenced from every skill's ODD header) |
| `ontology-schema.json` | Ontology TBox (`ontology-gen.sh` / `ontology-lint.sh` / `test-ontology.sh`) |
| `store-layout.json` | Canonical ai-context store layout (`ai-context-session-start.sh`, `store-map-gen.sh` / `store-map-lint.sh`, `ontology-gen.sh`) |
| `specs/` | Spec document templates incl. `spec-kit/` (`spec` skill) |
| `ci/` | Nightly automation samples: launchd plist example + routine doc (`ai-context-store-init.sh` points users here) |
| `pii/name-registry.example` | Sample name registry for the egress guard (`scripts/harness-setup.sh`) |

## Rule scopes

Always-on rules (`quality` / `safety` / `evidence-first` / `spec-fidelity` / `pii-protection`)
apply to every file; the path-scoped rule (`dependencies`) is injected only for matching paths;
`writing-ja` is opt-in via the `set-language` skill. The former `thinking-core` rule now ships as
the on-demand `thinking-core` skill (for sonnet / haiku and older-generation models only — never
loaded for 5-generation Fable / Opus).
