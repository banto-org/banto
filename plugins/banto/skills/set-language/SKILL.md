---
name: set-language
description: |
  **UTILITY SKILL** — Switch the Banto language between Japanese and English; persists the choice (survives plugin updates); load the new set with /reload-plugins (or a Claude Code restart). Also owns the opt-in toggle for the Japanese writing-style rule (writing-ja, default off).
  Triggers: "set language to japanese", "switch to english", "make banto japanese/english", 「言語を日本語にして」「英語に切り替えて」「言語設定」; writing-ja toggle: "turn the Japanese writing rule on/off", 「writing-ja をオンに/オフにして」「日本語ライティングルールを有効に/無効に」「文体ルールを外して/入れて」. Also invocable via /set-language.
  Do not use when: changing the *output* language of a single document (just write it in that language), or editing one skill's wording (direct Edit).
user-invocable: true
argument-hint: "<ja|en | 日本語|英語 | writing-ja on|off>"
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
2. copies `i18n/<lang>/{skills,agents,templates}` onto the active `skills/`, `agents/` and `templates/` (rules included),
3. stamps `skills/.banto-lang` with `<lang> <plugin-version>`,
4. reconciles the JA-specific `writing-ja` rule in `~/.claude/rules/` (via `writing-ja-toggle.sh sync`): deployed only when the language is JA **and** the user has opted in (see below; default off). Removes only unmodified copies.

After a future `claude plugin update`, the SessionStart hook `i18n-reconcile.sh` reads the saved
preference and **re-materializes the same language automatically** (so the choice is sticky).

## Step 3: Report

Tell the user, in their conversation language:
- which language is now active,
- that they must run **/reload-plugins** (or restart Claude Code) for the new skill set to load,
- that the choice will persist across future plugin updates.

## Variant: writing-ja rule toggle (opt-in, default off)

The Japanese writing-style rule (`writing-ja.md` — 体言止め sentence endings, katakana reduction,
etc.) is **opt-in**. It is injected only while a copy exists at `~/.claude/rules/writing-ja.md`,
and the toggle is what creates/removes that copy.

When the user asks to enable or disable the writing rule (not to switch language), run:

```sh
sh "$CLAUDE_PLUGIN_ROOT/scripts/writing-ja-toggle.sh" <on|off>
```

This:
1. persists the preference to `~/.claude/banto-writing-ja` (user scope — survives plugin updates; absent = off),
2. reconciles `~/.claude/rules/writing-ja.md`: `on` deploys it (JA language only), `off` removes the unmodified copy (personal edits are left in place with a notice).

Report: the new on/off state, and that sessions already running may keep the previous injection
until restarted. Note that `on` while the language is EN is saved but deploys only after
switching to JA.
