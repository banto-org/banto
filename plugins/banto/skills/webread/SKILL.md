---
name: webread
description: |
  **UTILITY SKILL** — Fetch the full body of a URL as clean Markdown "without any LLM summarization", so the main model reads it directly.
  Replacement for WebFetch (WebFetch returns a small-model summary, so the body cannot actually be verified).
  Triggers: given a URL with "read this", "check this", "look at the contents", "summarize this"; close reading of documentation/articles/blogs/GitHub pages.
  Do not use when: *searching for* URLs (WebSearch / research skill), local files (Read directly), direct `.md` links (use Read/curl, not WebFetch).
allowed-tools: Bash Read Write
user-invocable: true
argument-hint: "[URL]"
compatibility: Claude Code (requires python3, trafilatura)
---

# WebRead — Fetch a URL's full body without summarization

## Why WebRead instead of WebFetch

`WebFetch` returns the fetched page **summarized by a small model**. The main model never reads
the raw body, causing omissions and distortion (summaries can silently drop critical details).

WebRead extracts the full body with **trafilatura** (pure local, no LLM), and **the main model
Reads that full text directly**. When a summary is needed, the main model summarizes after reading
the full text (never delegating to a small model).

## Procedure

### 1. Fetch (static sites = news, blogs, docs, GitHub)

```sh
sh "$CLAUDE_PLUGIN_ROOT/scripts/webread.sh" "<URL>" > /tmp/webread-out.md
```

**Always Read the output in full** (full Markdown body with metadata). If stdout is short, reading it inline is fine.

### 2. SPA / JS-rendered sites (when trafilatura cannot extract the body)

trafilatura fetches static HTML, so JS-rendered SPAs may yield an empty body.
Only in that case, use the **2-step approach**:

1. Use Claude in Chrome (`mcp__claude-in-chrome__navigate` → `get_page_text`) or Playwright MCP
   (`mcp__playwright__browser_navigate` → `browser_evaluate` with `document.documentElement.outerHTML`)
   to obtain the rendered HTML and save it to a file.
2. Extract the body with `sh "$CLAUDE_PLUGIN_ROOT/scripts/webread.sh" --html <saved.html>`.

### 3. Summarize / answer (only when needed)

The main model summarizes/answers **after reading the full text**. Never hand the prompt to an
external small model the way WebFetch does. "Actually verifying the content" is this skill's reason to exist.

## Installing the dependency (if missing)

```sh
pip install --user trafilatura
```

When trafilatura is absent, webread.sh falls back to raw HTML via curl (tags included; the main model still reads it).

## Never do

- Use WebFetch (it defeats this skill's reason to exist). Unify URL close-reading on WebRead.
- State conclusions without Reading the fetched body (the same mistake as delegating to a summary model).
- Use it to search for URLs (that is WebSearch / the research skill).
