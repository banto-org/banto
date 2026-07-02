#!/bin/sh
# ontology-gen.sh — generate the repo ontology ABox into {base}/meta/ontology.{json,md} (idempotent).
#
# v1 = STATIC harness-layer + core: entities and relations that are DETERMINISTICALLY derivable from
# the harness manifests (hooks/hooks.json, skills/<n>/{SKILL.md,odd.yaml}, agents/*.md, templates/
# rules/*.md, scripts/*.sh, templates/store-layout.json) with grep/jq/sh — no ctags, no LLM. Prose-
# derived relations (invokes / excludes / conforms-to ...) are the concept layer (ontology-gen --scope
# full, later). The TBox (vocabulary) is templates/ontology-schema.json; ontology-lint.sh verifies.
#
# json is the source of truth; the .md index is a view rendered from it (always consistent).
# Fail-open: jq absent / base unresolved → exit 0 (nothing written). Idempotent: rewrites only when
# the content (excluding the generated stamp) changes, so SessionStart re-runs are cheap.
#
# Usage: ontology-gen.sh [--base <dir>] [--scope static|full]
set -u

command -v jq >/dev/null 2>&1 || exit 0

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT=${BANTO_PLUGIN_ROOT:-$(cd -- "$SCRIPT_DIR/.." && pwd)}
HOOKS="$PLUGIN_ROOT/hooks/hooks.json"
STORE_LAYOUT="$PLUGIN_ROOT/templates/store-layout.json"

BASE=""
SCOPE="static"
REPO=""
while [ $# -gt 0 ]; do
    case "$1" in
        --base)  BASE="${2:-}"; shift 2 ;;
        --scope) SCOPE="${2:-static}"; shift 2 ;;
        --repo)  REPO="${2:-}"; shift 2 ;;
        *) shift ;;
    esac
done
[ -n "$BASE" ] || BASE=$(sh "$PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD" 2>/dev/null)
[ -n "$BASE" ] && [ -d "$BASE" ] || exit 0
# the repo being described (core layer). Default: the git root of PWD, else PWD.
[ -n "$REPO" ] || REPO=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || echo "$PWD")

META="$BASE/meta"
OUTJSON="$META/ontology.json"
OUTMD="$META/ontology.md"
mkdir -p "$META" 2>/dev/null || exit 0

ENT=$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/onto-ent.$$")
REL=$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/onto-rel.$$")
REG=$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/onto-reg.$$")
TMPJSON=$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/onto-json.$$")
trap 'rm -f "$ENT" "$REL" "$REG" "$TMPJSON"' EXIT
: > "$ENT"; : > "$REL"; : > "$REG"

TAB=$(printf '\t')

# classify a store-layout owner string into an entity id (filesystem-resolved)
resolve_owner() {
    o="$1"
    case "$o" in
        *.sh) bb=$(basename "$o" .sh)
              if [ -f "$PLUGIN_ROOT/hooks/$o" ]; then printf 'hook:%s' "$bb"
              else printf 'script:%s' "$bb"; fi ;;
        *.py) printf 'script:%s' "$(basename "$o" .py)" ;;
        *)    if [ -d "$PLUGIN_ROOT/skills/$o" ]; then printf 'skill:%s' "$o"
              elif [ -f "$PLUGIN_ROOT/agents/$o.md" ]; then printf 'agent:%s' "$o"
              else printf 'skill:%s' "$o"; fi ;;
    esac
}

# --- registered hook basenames (from hooks.json) ---------------------------
if [ -f "$HOOKS" ]; then
    jq -r '.hooks | to_entries[] | .value[] | .hooks[]?.command' "$HOOKS" 2>/dev/null \
        | grep -oE '[A-Za-z0-9._-]+\.sh' | sed 's/\.sh$//' | sort -u > "$REG"
fi

# --- entities: skills (autonomy + user-invocable) --------------------------
for d in "$PLUGIN_ROOT"/skills/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    aut=$(sed -n 's/^autonomy_level:[[:space:]]*\([A-Za-z0-9]*\).*/\1/p' "$d/odd.yaml" 2>/dev/null | head -1)
    uinv=false
    grep -q '^user-invocable:[[:space:]]*true' "$d/SKILL.md" 2>/dev/null && uinv=true
    jq -nc --arg id "skill:$name" --arg a "$aut" --argjson u "$uinv" \
        '{id:$id,type:"skill",autonomy:(if $a=="" then null else $a end),user_invocable:$u}' >> "$ENT"
done

# --- entities: agents (tools) ----------------------------------------------
for f in "$PLUGIN_ROOT"/agents/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .md)
    tools=$(sed -n 's/^tools:[[:space:]]*\(.*\)/\1/p' "$f" | head -1)
    jq -nc --arg id "agent:$name" --arg t "$tools" \
        '{id:$id,type:"agent",tools:(if $t=="" then null else $t end)}' >> "$ENT"
done

# --- entities: hooks (registered true/false) + gates relations -------------
for f in "$PLUGIN_ROOT"/hooks/*.sh; do
    [ -f "$f" ] || continue
    b=$(basename "$f" .sh)
    reg=false
    grep -qxF "$b" "$REG" && reg=true
    jq -nc --arg id "hook:$b" --argjson r "$reg" '{id:$id,type:"hook",registered:$r}' >> "$ENT"
done
if [ -f "$HOOKS" ]; then
    jq -r '.hooks | to_entries[] | .key as $ev | .value[] | (.matcher // "*") as $m
           | .hooks[]?.command | "\($ev)'"$TAB"'\($m)'"$TAB"'\(.)"' "$HOOKS" 2>/dev/null \
    | while IFS="$TAB" read -r ev m cmd; do
        case "$cmd" in *.sh*) ;; *) continue ;; esac
        b=$(printf '%s' "$cmd" | sed -E 's#.*/([A-Za-z0-9._-]+)\.sh.*#\1#')
        jq -nc --arg from "hook:$b" --arg to "event:$ev:$m" --arg m "$m" \
            '{from:$from,type:"gates",to:$to,matcher:$m}' >> "$REL"
    done
fi

# --- entities: scripts (scripts/*.sh helpers, not registered hooks) --------
for f in "$PLUGIN_ROOT"/scripts/*.sh "$PLUGIN_ROOT"/scripts/*.py; do
    [ -f "$f" ] || continue
    b=$(basename "$f"); b=${b%.sh}; b=${b%.py}
    jq -nc --arg id "script:$b" '{id:$id,type:"script"}' >> "$ENT"
done

# --- entities: rules -------------------------------------------------------
for f in "$PLUGIN_ROOT"/templates/rules/*.md; do
    [ -f "$f" ] || continue
    b=$(basename "$f" .md)
    jq -nc --arg id "rule:$b" '{id:$id,type:"rule"}' >> "$ENT"
done

# --- entities: store-buckets + writes-to (owners) --------------------------
if [ -f "$STORE_LAYOUT" ]; then
    jq -r '.buckets[] | [.path, .scope, (.gitignore|tostring), ((.owners // [])|join(","))] | @tsv' "$STORE_LAYOUT" 2>/dev/null \
    | while IFS="$TAB" read -r path scope gi owners; do
        jq -nc --arg id "bucket:$path" --arg s "$scope" --argjson g "$gi" \
            '{id:$id,type:"store-bucket",scope:$s,gitignore:$g}' >> "$ENT"
        printf '%s\n' "$owners" | tr ',' '\n' | while IFS= read -r o; do
            [ -n "$o" ] || continue
            from=$(resolve_owner "$o")
            jq -nc --arg from "$from" --arg to "bucket:$path" \
                '{from:$from,type:"writes-to",to:$to}' >> "$REL"
        done
    done
fi

# --- core layer: the project repo (structure + deps), language-agnostic, ALWAYS emitted ---------
# So a non-banto repo still gets a non-empty ABox (files/dirs/dep-manifests) even with no harness and
# no analysis tool. Best-effort dep extraction (npm / pypi for v1); graceful when a manifest is absent.
if [ -d "$REPO" ]; then
    rname=$(basename "$REPO")
    jq -nc --arg id "repo:$rname" --arg n "$rname" '{id:$id,type:"repo",name:$n}' >> "$ENT"
    for sub in "$REPO"/*/; do
        [ -d "$sub" ] || continue
        b=$(basename "$sub")
        case "$b" in .git|.svn|.hg|node_modules|dist|build|target|vendor|.venv|__pycache__) continue ;; esac
        jq -nc --arg id "dir:$b" --arg p "$b" '{id:$id,type:"directory",path:$p}' >> "$ENT"
        jq -nc --arg from "repo:$rname" --arg to "dir:$b" '{from:$from,type:"contains",to:$to}' >> "$REL"
    done
    if [ -f "$REPO/package.json" ]; then
        jq -r '((.dependencies//{})+(.devDependencies//{}))|keys[]?' "$REPO/package.json" 2>/dev/null \
        | while IFS= read -r dep; do
            [ -n "$dep" ] || continue
            jq -nc --arg id "dep:$dep" '{id:$id,type:"external-dep",ecosystem:"npm"}' >> "$ENT"
            jq -nc --arg from "repo:$rname" --arg to "dep:$dep" '{from:$from,type:"depends-on",to:$to}' >> "$REL"
          done
    fi
    if [ -f "$REPO/requirements.txt" ]; then
        grep -oE '^[A-Za-z0-9][A-Za-z0-9._-]*' "$REPO/requirements.txt" 2>/dev/null \
        | while IFS= read -r dep; do
            [ -n "$dep" ] || continue
            jq -nc --arg id "dep:$dep" '{id:$id,type:"external-dep",ecosystem:"pypi"}' >> "$ENT"
            jq -nc --arg from "repo:$rname" --arg to "dep:$dep" '{from:$from,type:"depends-on",to:$to}' >> "$REL"
          done
    fi
fi

# --- doc-layer: index the store's documents (navigation ledger; metadata only, NO content) --------
# The COMPLETE list — every decision/doc becomes a `document` entity with metadata, so an agent is
# aware of every document (no recall gap) and navigates by deterministic filter, not RAG retrieval.
_doctitle() {
    t=$(sed -n 's/^title:[[:space:]]*//p' "$1" 2>/dev/null | head -1)
    [ -z "$t" ] && t=$(grep -m1 '^# ' "$1" 2>/dev/null | sed 's/^#[[:space:]]*//')
    printf '%s' "$t"
}
# frontmatter の related: リスト（素朴な YAML ブロック形式）を列挙
_docrelated() {
    awk 'NR==1 && $0!="---"{exit} /^---$/{c++; if(c>1) exit; next}
         c==1 && /^related:[[:space:]]*$/{f=1; next}
         c==1 && f && /^[[:space:]]+-[[:space:]]/{sub(/^[[:space:]]+-[[:space:]]+/,""); print; next}
         c==1 && f{f=0}' "$1" 2>/dev/null
}
# related エントリ（.md / author 接尾辞を欠く prefix 形が多い）を実ファイルへ解決し、
# 解決できたエッジのみ references として台帳へ（TBox doc-layer で宣言済みの follow-up 実装）
_emit_references() { # $1=source file  $2=source rel（doc:<rel> の <rel>）
    _docrelated "$1" | while IFS= read -r _rr; do
        [ -n "$_rr" ] || continue
        if [ -f "$BASE/$_rr" ]; then _tgt="$BASE/$_rr"
        else _tgt=$(ls "$BASE/$_rr"*.md 2>/dev/null | head -1); fi
        [ -n "$_tgt" ] && [ -f "$_tgt" ] || continue
        _trel=${_tgt#"$BASE/"}
        # 台帳（doc-layer）に entity として載る decisions/ docs/ のみエッジ化（L2 端点解決を保つ。
        # workspaces 等の doc-layer 収録は R2 実測で既知の fidelity 改善候補 — 収録時にこの制限を外す）
        case "$_trel" in decisions/*|docs/*) ;; *) continue ;; esac
        jq -nc --arg from "doc:$2" --arg to "doc:$_trel" \
            '{from:$from,type:"references",to:$to}' >> "$REL"
    done
}
if [ -d "$BASE/decisions" ]; then
    for f in "$BASE"/decisions/*.md; do
        [ -f "$f" ] || continue
        rel="decisions/$(basename "$f")"
        t=$(_doctitle "$f")
        a=$(sed -n 's/^author:[[:space:]]*//p' "$f" 2>/dev/null | head -1)
        s=$(sed -n 's/^status:[[:space:]]*//p' "$f" 2>/dev/null | head -1)
        jq -nc --arg id "doc:$rel" --arg t "$t" --arg a "$a" --arg s "$s" \
            '{id:$id,type:"document",doc_type:"decision",title:(if $t=="" then null else $t end),author:(if $a=="" then null else $a end),status:(if $s=="" then null else $s end)}' >> "$ENT"
        _emit_references "$f" "$rel"
    done
fi
if [ -d "$BASE/docs" ]; then
    find "$BASE/docs" -type f \( -name '*.md' -o -name '*.html' \) 2>/dev/null | while IFS= read -r f; do
        rel="docs/${f#"$BASE/docs/"}"
        b=$(basename "$f")
        case "$rel" in
            docs/research/*)   dt="research" ;;
            docs/specs/*)      # SDD triple: distinguish spec / plan / tasks by filename suffix
                               case "$b" in *_plan.md) dt="plan" ;; *_tasks.md) dt="tasks" ;; *) dt="spec" ;; esac ;;
            docs/knowledges/*) dt="knowledge" ;;
            *) dt=$(printf '%s' "$b" | sed -n 's/^\[\([A-Za-z]*\)\].*/\1/p'); [ -z "$dt" ] && dt="doc" ;;
        esac
        t=$(_doctitle "$f")   # real title (frontmatter / first heading); fall back to filename slug
        [ -z "$t" ] && t=$(printf '%s' "$b" | sed -E 's/^\[[A-Za-z]+\][[:space:]]*//; s/\.(md|html)$//')
        jq -nc --arg id "doc:$rel" --arg dt "$dt" --arg t "$t" \
            '{id:$id,type:"document",doc_type:$dt,title:$t}' >> "$ENT"
        _emit_references "$f" "$rel"
    done
fi

# --- concept layer (--scope full): prose-derived relations via LLM, cached by hash --------------
# Determinism split (same as i18n-gen): the EXTRACTION is delegated to an LLM (non-deterministic),
# but WHICH skills need re-extraction is decided deterministically by content hash, and the result is
# cached. Cost ceiling caps LLM calls per run. Extractor is swappable ($BANTO_ONTOLOGY_EXTRACT_CMD,
# default `claude -p`) so tests can stub it. The extractor returns {type,to} pairs; this script owns
# `from` (= the skill), so a mis-extraction can never mislabel the source.
if [ "$SCOPE" = "full" ]; then
    CACHE="$META/ontology-cache"
    mkdir -p "$CACHE" 2>/dev/null
    EXTRACT=${BANTO_ONTOLOGY_EXTRACT_CMD:-claude -p}
    MAX=${BANTO_ONTOLOGY_MAX_CALLS:-20}
    calls=0; skipped=0
    _sha() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }
    PROMPT='Read this Banto SKILL.md and extract ONLY the typed relations it EXPLICITLY declares.
Output a JSON array of objects {"type":..,"to":..} (no "from" — the caller adds it), no prose, no code fence.
Allowed type (harness-layer TBox):
- excludes / defers-to  <- the "使わない場面" / "Do not use when" section names other skills
- invokes               <- calls another skill as a step (to = "skill:<name>")
- delegates-to          <- delegates to an agent (to = "agent:<name>")
- hands-off-to          <- pipeline handoff to the next skill
- escalates-to          <- escalates to another skill on a condition
- specializes           <- inherits/specializes another skill
- conforms-to           <- follows a named rule (to = "rule:<name>")
to = "skill:<name>" | "agent:<name>" | "rule:<name>". Emit [] if none are explicit.
--- SKILL.md ---
'
    for d in "$PLUGIN_ROOT"/skills/*/; do
        [ -d "$d" ] || continue
        name=$(basename "$d")
        skm="$d/SKILL.md"
        [ -f "$skm" ] || continue
        h=$(_sha "$skm")
        cf="$CACHE/skill-$name.json"
        rels="[]"
        if [ -f "$cf" ] && [ "$(jq -r '.hash // ""' "$cf" 2>/dev/null)" = "$h" ]; then
            rels=$(jq -c '.relations // []' "$cf" 2>/dev/null)
        elif [ "$calls" -lt "$MAX" ]; then
            raw=$($EXTRACT "$PROMPT$(cat "$skm")" 2>/dev/null)
            if printf '%s' "$raw" | jq -e 'type=="array"' >/dev/null 2>&1; then
                rels=$(printf '%s' "$raw" | jq -c '.')
                jq -n --arg h "$h" --argjson r "$rels" '{hash:$h,relations:$r}' > "$cf" 2>/dev/null
            fi
            calls=$((calls+1))
        else
            skipped=$((skipped+1))
        fi
        # harden against bad LLM output: keep only known concept relation types + a well-formed `to`.
        printf '%s' "$rels" | jq -c --arg from "skill:$name" '
            ["invokes","delegates-to","spawns-parallel","hands-off-to","escalates-to","specializes","excludes","defers-to","conforms-to"] as $ok
            | .[]? | select((.type as $t | $ok | index($t)) and (.to|type=="string") and (.to|test("^(skill|agent|rule|hook):")))
            | {from:$from,type:.type,to:.to}' >> "$REL" 2>/dev/null
    done
    [ "$skipped" -gt 0 ] && printf 'ontology-gen: concept layer skipped %s skills (cost ceiling %s)\n' "$skipped" "$MAX" >&2
fi

# --- assemble json (no stamp yet, for idempotent compare) ------------------
ENTITIES=$(jq -s 'unique_by(.id) | sort_by(.type,.id)' "$ENT" 2>/dev/null) || exit 0
RELATIONS=$(jq -s 'unique | sort_by(.type,.from,.to)' "$REL" 2>/dev/null) || exit 0
jq -n --argjson e "$ENTITIES" --argjson r "$RELATIONS" --arg scope "$SCOPE" '{
    schema_version: 1,
    tbox: "plugins/banto/templates/ontology-schema.json",
    generator: "ontology-gen.sh",
    scope: $scope,
    entities: $e,
    relations: $r
}' > "$TMPJSON" || exit 0

# --- idempotent: rewrite only when content (minus stamp) changed -----------
if [ -f "$OUTJSON" ]; then
    old=$(jq -S 'del(.generated)' "$OUTJSON" 2>/dev/null)
    new=$(jq -S '.' "$TMPJSON" 2>/dev/null)
    [ "$old" = "$new" ] && exit 0
fi

STAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")
jq --arg s "$STAMP" '.generated=$s' "$TMPJSON" > "$OUTJSON" 2>/dev/null || exit 0

# --- render the .md as a QUERY GUIDE (schema + example jq); the data lives in the json ----------
# The ontology is queried, not read wholesale: cross-cutting structure questions cost far fewer tokens
# when answered by a jq query (small output) than by loading the full ABox into context. This guide
# carries the schema + example queries so an agent can query ontology.json without reading it.
{
    echo "<!-- AUTO-ONTOLOGY: generated by scripts/ontology-gen.sh. Do not edit by hand (overwritten). -->"
    echo "# Repo Ontology — $(basename "$BASE") — query guide"
    echo ""
    echo "> Query \`meta/ontology.json\` with \`jq\`; do not read it wholesale. This guide is the schema + example queries. TBox: \`templates/ontology-schema.json\`; verified by \`ontology-lint.sh\`. Generated $STAMP."
    echo ""
    echo "## Size"
    echo ""
    printf -- '- %s entities / %s relations. By entity type: ' \
        "$(jq '.entities|length' "$OUTJSON")" "$(jq '.relations|length' "$OUTJSON")"
    jq -r '[.entities[].type] | group_by(.) | map("\(.[0])=\(length)") | join(", ")' "$OUTJSON"
    echo ""
    echo "## Schema"
    echo ""
    echo "- \`.entities[]\` = { id, type, autonomy?, user_invocable?, registered?, scope?, gitignore? }"
    echo "- \`.relations[]\` = { from, type, to }"
    echo "- id formats: \`skill:<n>\` \`agent:<n>\` \`hook:<n>\` \`rule:<n>\` \`script:<n>\` \`bucket:<path>\` \`event:<Event>:<matcher>\` \`dir:<n>\` \`dep:<n>\` \`repo:<n>\`"
    echo "- relation types: \`gates\` (hook→event) · \`writes-to\` (skill/hook→bucket) · \`contains\` · \`depends-on\` · \`references\` (doc→doc, from \`related:\` frontmatter); concept-layer types (\`invokes\` \`excludes\` \`conforms-to\` …) appear only under \`--scope full\`"
    echo ""
    echo "## Example queries (jq over meta/ontology.json)"
    echo ""
    echo '```sh'
    echo '# hooks gating a given event, e.g. PreToolUse:Bash'
    echo 'jq -r "[.relations[]|select(.type==\"gates\" and .to==\"event:PreToolUse:Bash\").from]" meta/ontology.json'
    echo '# skills with a given autonomy, e.g. L3'
    echo 'jq -r "[.entities[]|select(.type==\"skill\" and .autonomy==\"L3\").id]" meta/ontology.json'
    echo '# what a skill writes to'
    echo 'jq -r "[.relations[]|select(.type==\"writes-to\" and .from==\"skill:ai-context\").to]" meta/ontology.json'
    echo '# skills writing to BOTH decisions and docs (join)'
    echo 'jq -r "([.relations[]|select(.type==\"writes-to\" and .to==\"bucket:decisions\").from]) as \$d|[.relations[]|select(.type==\"writes-to\" and .to==\"bucket:docs\").from]|map(select(.==(\$d[])))" meta/ontology.json'
    echo '```'
} > "$OUTMD" 2>/dev/null

exit 0
