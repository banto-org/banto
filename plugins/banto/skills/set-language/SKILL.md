---
name: set-language
description: |
  **UTILITY SKILL** — Switch the Banto language between Japanese and English; persists the choice (survives plugin updates) and requires a Claude Code restart to load the new set.
  Triggers: "set language to japanese", "switch to english", "make banto japanese/english", 「言語を日本語にして」「英語に切り替えて」「言語設定」. Also invocable via /set-language.
  Do not use when: changing the *output* language of a single document (just write it in that language), or editing one skill's wording (direct Edit).
user-invocable: true
argument-hint: "<ja|en | 日本語|英語>"
allowed-tools: Bash
compatibility: Claude Code (requires bash, jq)
---

# /set-language — Switch Banto language (JA ⇄ EN) / banto の言語を切り替え

Banto ships **JA-canonical** skills and **auto-generated EN** skills. This skill makes one of
them the active set and remembers the choice across plugin updates.

This is the one deliberately bilingual switcher: it must be discoverable in any language so a user
on the EN set can switch to JA and vice-versa.

## Step 1: Resolve the argument to `ja` or `en`

Map `$ARGUMENTS` to a language code:

- `ja` ← `ja`, `japanese`, `jp`, 「日本語」「にほんご」「和」
- `en` ← `en`, `english`, 「英語」「えいご」

If `$ARGUMENTS` is empty or ambiguous, ask the user once (text) which language they want — do not guess.

## Step 2: Apply (persist preference + materialize active set)

Run, substituting the resolved code for `<lang>`:

```sh
sh "$CLAUDE_PLUGIN_ROOT/scripts/set-language.sh" <lang>
```

This:
1. writes the preference to `~/.claude/banto-language` (user scope — **survives plugin updates**),
2. copies `i18n/<lang>/{skills,agents}` onto the active `skills/` and `agents/`,
3. stamps `skills/.banto-lang` with `<lang> <plugin-version>`,
4. syncs the JA-specific `writing-ja` rule in `~/.claude/rules/` to the language (deploys it for JA, removes the unmodified copy for EN; no-op if the harness is not yet set up).

After a future `claude plugin update`, the SessionStart hook `i18n-reconcile.sh` reads the saved
preference and **re-materializes the same language automatically** (so the choice is sticky).

## Step 3: Report

Tell the user, in their conversation language:
- which language is now active,
- that they must **restart Claude Code** for the new skill set to load,
- that the choice will persist across future plugin updates.
