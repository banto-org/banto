# Step 4: Claude Design handoff (when UI is involved)

When the target involves UI (LP, dashboard, mobile screen, landing page, etc.). Claude Design is a **Research Preview released 2026-04-17, Pro/Max/Team/Enterprise only, powered by the latest Opus**.

## 4.1 Confirm whether it can be used

```
UI design is needed. Is the plan to prototype first with Claude Design (claude.ai/design)
and then proceed to implementation OK?

- Yes: build the prototype in Claude.ai's Design mode → hand off to Claude Code via the official flow
- No: substitute with the Design Doc's UI section (wireframe + component breakdown)
```

If there is no Pro/Max-or-higher subscription, automatically route to the `No` flow.

## 4.2 Prompt structure to pass to Claude Design (in the Yes case)

Prompt the user to fill in the **4-element template**:

- **Goal**: what the UI is meant to achieve (1-2 sentences)
- **Layout**: layout specification (number of columns, nav position, mobile support, etc.)
- **Content**: content elements to include (sections, data types, images)
- **Audience**: target users (age group, technical level, usage context)

**Supplementary material (optional, improves accuracy)**:
- Design system (Figma file name / token list / brand guide)
- Screenshots of reference UI
- **Initial codebase link** (reflects existing code conventions, **strongly recommended**)
- Existing drafts under `docs/specs/designs/`

## 4.3 Claude Design → Claude Code handoff (the official 1-step flow)

1. After completing the prototype in Claude Design, choose **Export → "Hand off to Claude Code"**
2. A bundle ZIP is auto-generated (contents: `README.md` + `prototype.html` + `assets/`)
3. Claude Design issues a paste-ready prompt (with the bundle URL embedded)
4. Just **paste it into Claude Code** to start implementation

**Where to expand the bundle**:
- Recommended: save under `docs/specs/designs/{topic}/` (shared within the project)
- Or have Claude Code reference the URL directly (temporary)

**Bundle contents**:
- `README.md` (about 26KB): design token definitions, component boundaries, implementation priority, recommended adopted variants. Includes concrete instructions for the AI such as "implement tokens first (they block everything else)"
- `prototype.html` (about 72KB): a clickable HTML prototype containing multiple variants
- `assets/`: images, icons, etc.

Claude Code reads `README.md` and generates an implementation that follows the existing codebase conventions.

## 4.4 Constraints and caveats (research preview)

- No multiplayer support
- **Cannot export Figma files directly**
- API **not yet released**
- The Pro plan has a tight weekly limit (a report of 58% consumed in 2 sessions) → **Max recommended**
- **There is a hallucination risk for numbers and legal text** → user review is required before production
- Fallbacks (Pro-or-below / when Claude Design is unavailable):
  - v0.dev → Claude Code
  - Via Figma + Figma MCP (banto's figma-implement-design skill)

## 4.5 The `No` route (Design Doc alternative)

When Claude Design cannot be used / UI is not important:
- Define the UI in prose with the Design Doc's "3.1 Overview diagram" and "3.2 Components"
- Substitute the wireframe with ASCII art or Mermaid notation
- Fall back to the Figma-implement-design skill if needed
