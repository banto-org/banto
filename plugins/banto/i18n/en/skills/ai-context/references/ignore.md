# /ai-context ignore — denylist management details

## Purpose

`banto`'s SessionStart / UserPromptSubmit hooks auto-scaffold the project skeleton on the central-store side for projects inside a git work tree (store-first: nothing is created in the repo). For projects you don't want to register in the store — prototypes, other people's repositories, temporary work directories, etc. — let the user suppress them on a per-path basis.

denylist file: `~/.claude/banto-ignore`
(overridable with the environment variable `BANTO_IGNORE_FILE`)

File format:
- one path per line
- lines starting with `#` are comments, blank lines are ignored
- `~` / `~/` expand to `$HOME`
- a trailing comment (a space is required before the ` #`) is also allowed
- matching: prefix match (CWD == path or CWD is under path)

## Sub-subcommands

Process the 2nd token of `$ARGUMENTS`.

- empty → run list + guide a menu (add current path / add arbitrary / remove)
- `list`        → list display (with line numbers)
- `add`         → add the current CWD (absolute path of `pwd`)
- `add <path>`  → normalize `<path>` to an absolute path and add
- `remove`      → after showing list, interactively input a number
- `remove <N>`  → delete line number N (1-indexed, valid lines only)

## Common: file preparation

```bash
IGNORE_FILE="${BANTO_IGNORE_FILE:-$HOME/.claude/banto-ignore}"
mkdir -p "$(dirname "$IGNORE_FILE")"
[ -f "$IGNORE_FILE" ] || cat > "$IGNORE_FILE" <<'EOF'
# banto ignore list
# 1 path per line; # for comments; ~/ expands to $HOME
EOF
```

## list implementation

```bash
awk 'BEGIN{n=0}
     /^[[:space:]]*$/{next}
     /^[[:space:]]*#/{next}
     {n++; sub(/[[:space:]]+#.*$/,""); sub(/^[[:space:]]+/,""); sub(/[[:space:]]+$/,"")
      printf "%d\t%s\n", n, $0}' "$IGNORE_FILE"
```

Example output:
```
Registered ignore paths (~/.claude/banto-ignore):
  1  /Users/you/scratch
  2  ~/Documents/clients/foo
  3  /tmp/sandbox

Total: 3
```

If 0, display "(none registered)".

## add implementation

No argument: `TARGET=$(pwd)`

With argument:
```bash
RAW="$1"
case "$RAW" in
  '~') TARGET="$HOME" ;;
  '~/'*) TARGET=$(printf '%s' "$RAW" | sed "s|^~/|$HOME/|") ;;
  /*) TARGET="$RAW" ;;
  *) TARGET="$(cd "$RAW" 2>/dev/null && pwd)" || { echo "Error: cannot resolve path: $RAW"; exit 1; } ;;
esac
TARGET="${TARGET%/}"
```

`~/` expansion does not work as intended with `${RAW#~/}` in zsh and others, so substitute reliably via sed.

Duplicate check:
```bash
if grep -Fxq "$TARGET" "$IGNORE_FILE" 2>/dev/null; then
    echo "Already registered: $TARGET"
    exit 0
fi
```

Append:
```bash
[ -s "$IGNORE_FILE" ] && [ "$(tail -c1 "$IGNORE_FILE" | xxd -p)" != "0a" ] && echo "" >> "$IGNORE_FILE"
echo "$TARGET" >> "$IGNORE_FILE"
echo "Added: $TARGET"
echo ""
echo "From the next session on, banto's automatic store scaffold is suppressed for this path (and below)."
echo "A project dir already created on the store side is not changed (delete it manually if unneeded)."
```

## remove implementation

With argument (numeric): identify and delete the original line corresponding to the valid line number N of list (preserving the up/down relationship of comment lines)

No argument:
1. Display list
2. Confirm in text "Which number(s) to delete? (multiple allowed comma-separated, cancel to abort)"
3. Parse the input and delete the matching lines (for multiple deletions, process from the larger line number first)

Pseudocode of the implementation:
```bash
remove_by_index() {
    target_n="$1"
    awk -v target="$target_n" '
        BEGIN{n=0}
        /^[[:space:]]*$/{print; next}
        /^[[:space:]]*#/{print; next}
        {n++; if (n != target) print}
    ' "$IGNORE_FILE" > "$IGNORE_FILE.tmp" && mv "$IGNORE_FILE.tmp" "$IGNORE_FILE"
}
```

## No argument (menu)

```
Registered ignore paths (~/.claude/banto-ignore):
  1  /Users/you/scratch
  2  ~/Documents/clients/foo

Operations:
  /ai-context ignore add            ← add the current CWD ({pwd})
  /ai-context ignore add <path>     ← add an arbitrary path
  /ai-context ignore remove <N>     ← delete line number N
  /ai-context ignore list           ← list display
```

## Safety rules

- Do not delete a project dir already created on the store side via ignore add (suppression is for new scaffolds only)
- denylist editing is text append/delete only. Preserve existing comments
