#!/bin/sh
# plugin-audit-consistency.sh — cross-skill reference consistency (Axis 15: 相関/参照整合).
#
# Finds "the same place referenced with different spellings" across all skills — the divergence
# class that store-map-lint can't see because it needs no manifest: pure cross-reference clustering.
#   Check 1: same store sub-path referenced via >1 base-prefix spelling ({base} / {BASE} / <base> / .ai-context)
#   Check 2: base-prefix distribution + non-canonical occurrences (canonical = {base})
#   Check 3: same artifact type declared with >1 date-naming format (decisions / checkpoint / research)
#
# Output: grouped findings with file:line. Exit warn-only (0) by default; --strict exits 1 on Check 1/3
# divergence. --quiet prints nothing when clean. Fail-open: no skills dir → exit 0.
#
# Usage: plugin-audit-consistency.sh [plugin_dir] [--strict] [--quiet]
set -u

STRICT=0; QUIET=0; PLUGIN_DIR=""
for a in "$@"; do
    case "$a" in
        --strict) STRICT=1 ;;
        --quiet)  QUIET=1 ;;
        -*) ;;
        *) [ -z "$PLUGIN_DIR" ] && PLUGIN_DIR="$a" ;;
    esac
done

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
[ -n "$PLUGIN_DIR" ] || PLUGIN_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
SKILLS_DIR="$PLUGIN_DIR/skills"
[ -d "$SKILLS_DIR" ] || exit 0

TMP=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/pa-consistency.$$"); mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT
: > "$TMP/report"
out() { printf '%s\n' "$1" >> "$TMP/report"; }

# ---- collect every base-relative path token: (subpath, prefix, file:line) ----
: > "$TMP/tokens"
find "$SKILLS_DIR" -type f \( -name '*.md' -o -name 'odd.yaml' \) 2>/dev/null | while IFS= read -r f; do
    rel=${f#$PLUGIN_DIR/}
    grep -nE '(\{[bB][aA][sS][eE]\}|<base>|\.ai-context)/[A-Za-z0-9_./<>-]+' "$f" 2>/dev/null | while IFS= read -r line; do
        ln=${line%%:*}
        linetext=${line#*:}
        # a line that explicitly contrasts the legacy path ("legacy は …" / 旧 / レガシー) is intentional —
        # don't count its .ai-context mention as a divergence. Likewise a bare-path list entry
        # (e.g. a scan-exclusion list `.ai-context/sessions,`) is not a store-write declaration.
        islegacy=no
        case "$linetext" in *legacy*|*レガシー*|*旧\ *|*旧来*) islegacy=yes ;; esac
        trimmed=$(printf '%s' "$linetext" | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//')
        case "$trimmed" in
            .ai-context/*) case "$trimmed" in *' '*|*'`'*) ;; *) islegacy=yes ;; esac ;;
        esac
        printf '%s\n' "$line" | grep -oE '(\{[bB][aA][sS][eE]\}|<base>|\.ai-context)/[A-Za-z0-9_./<>-]+' | while IFS= read -r tok; do
            prefix=$(printf '%s' "$tok" | sed -E 's#/.*##')
            subpath=$(printf '%s' "$tok" | sed -E 's#^[^/]+/##; s#/+$##')
            # skip the "...": prose placeholders and bare base
            case "$subpath" in ''|.|..|...|'<absolute path>') continue ;; esac
            # skip intentional legacy-contrast .ai-context mentions
            [ "$prefix" = ".ai-context" ] && [ "$islegacy" = yes ] && continue
            printf '%s\t%s\t%s:%s\n' "$subpath" "$prefix" "$rel" "$ln" >> "$TMP/tokens"
        done
    done
done

# ---- Check 1: same sub-path, multiple base-prefix spellings ----
c1=0
if [ -s "$TMP/tokens" ]; then
    cut -f1 "$TMP/tokens" | sort -u | while IFS= read -r sp; do
        prefixes=$(awk -F'\t' -v s="$sp" '$1==s{print $2}' "$TMP/tokens" | sort -u)
        n=$(printf '%s\n' "$prefixes" | grep -c .)
        if [ "$n" -gt 1 ]; then
            out "  [1 same-place/diff-spelling] '$sp' は $n 通りの綴りで参照されている:"
            printf '%s\n' "$prefixes" | while IFS= read -r pf; do
                locs=$(awk -F'\t' -v s="$sp" -v p="$pf" '$1==s && $2==p{printf "%s ", $3}' "$TMP/tokens")
                out "      $pf/$sp  ←  $locs"
            done
        fi
    done
    c1=$(grep -c "^  \[1 " "$TMP/report" 2>/dev/null); [ -n "$c1" ] || c1=0
fi

# ---- Check 2: base-prefix distribution (canonical = {base}) ----
out "  [2 prefix-tally] base 接頭辞の分布（正準 = {base}）:"
for pf in '{base}' '{BASE}' '<base>' '.ai-context'; do
    cnt=$(awk -F'\t' -v p="$pf" '$2==p' "$TMP/tokens" 2>/dev/null | wc -l | tr -d ' ')
    [ "${cnt:-0}" -gt 0 ] && out "      $pf : $cnt 箇所"
done
noncanon=$(awk -F'\t' '$2!="{base}"' "$TMP/tokens" 2>/dev/null | wc -l | tr -d ' ')

# ---- Check 3: artifact naming-format divergence (date forms) ----
# Cluster the date-format tokens declared near each artifact keyword.
c3=0
fmt_of() { printf '%s' "$1" | grep -oE 'YYYY-MM-DD(-HHMMSS|_HHMMSS|_NNN)?' | head -1; }
for kw in decisions checkpoint research specs; do
    : > "$TMP/fmt"
    grep -rhnE "$kw" "$SKILLS_DIR" 2>/dev/null | grep -E 'YYYY-MM-DD' | while IFS= read -r l; do
        ff=$(fmt_of "$l"); [ -n "$ff" ] && echo "$ff" >> "$TMP/fmt"
    done
    forms=$(sort -u "$TMP/fmt" 2>/dev/null | grep -c . 2>/dev/null); [ -n "$forms" ] || forms=0
    if [ "${forms:-0}" -gt 1 ]; then
        list=$(sort -u "$TMP/fmt" | tr '\n' ' ')
        # decisions intentionally carries dual format (grandfather) — mark it as known, not a hard finding
        if [ "$kw" = decisions ]; then
            out "  [3 naming/info] '$kw' は複数の日付形式を併記: $list （grandfather 仕様＝意図的・是正不要）"
        else
            out "  [3 naming-divergence] '$kw' の日付形式が不一致: $list （1 形式に統一推奨）"
            c3=$((c3 + 1))
        fi
    fi
done

# ---- report ----
hard=$((c1 + c3))
if [ "$hard" -eq 0 ] && [ "$noncanon" -eq 0 ]; then
    [ "$QUIET" -eq 1 ] || echo "plugin-audit-consistency: clean — 同一参照先の綴り不一致なし・接頭辞は {base} に統一・命名形式の不一致なし。"
    exit 0
fi
if [ "$QUIET" -eq 1 ] && [ "$hard" -eq 0 ]; then
    # only the soft non-canonical prefix note remains; stay silent in quiet mode
    exit 0
fi

echo "=== plugin-audit Axis 15（相関/参照整合）: 綴り不一致 $c1 / 命名不一致 $c3 / 非正準接頭辞 $noncanon 箇所 ==="
sort "$TMP/report"
echo "  正準: 全 store パスは {base}/ で綴る（{BASE} / <base> / .ai-context は非正準）。"
[ "$STRICT" -eq 1 ] && [ "$hard" -gt 0 ] && exit 1
exit 0
