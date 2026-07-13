# Practical mermaid patterns

The existing html-doc skill's diagrams.md covers the theme-header format, the render pipeline via
`render-diagram.sh`, and inline SVG embedding. This guide specializes in what comes before that:
practical patterns for the notation itself. See diagrams.md for the render pipeline — not restated here.

## Choosing which diagram type to use

For the chronological order of an exchange or API calls, make `sequenceDiagram` the first choice.
For branching logic or decisions, use `flowchart`. For state transitions (a finite set of states
like "pending → approved → rejected"), use `stateDiagram-v2`. For a schedule, use `gantt`. Mixing up
these four causes the reader to lose the exact axis they were meant to read — chronology, branching, or state.

| What to show | Notation | Common misuse |
|---|---|---|
| Order of API calls / an exchange | `sequenceDiagram` | Written as a flowchart, trying to express order with arrows alone until they cross |
| Conditional branching / process flow | `flowchart LR` (left-to-right by default) | Written as a stateDiagram, cramming transition conditions into labels |
| States and transition conditions | `stateDiagram-v2` | Faked with flowchart arrow labels, so the initial/final state never appears in the diagram |
| Schedule / milestones | `gantt` | Content a table would suffice for is forced into gantt, producing bars with no dependencies |

## Practical sequence-diagram patterns

Declare participants explicitly with `participant`, in the order they appear — don't rely on
mermaid's automatic reordering. Always give them an alias, since Japanese labels wrap without one.

```
sequenceDiagram
  participant U as User
  participant W as Web server
  participant D as DB

  U->>W: Submit request
  activate W
  W->>D: Save request data
  D-->>W: Save complete
  W-->>U: Return receipt number
  deactivate W

  Note over U,W: First-pass intake ends here
```

Use `->>` for synchronous calls and `-->>` for responses. `activate`/`deactivate` render an
in-progress bar, but with more than 4 participants the bars overlap and become hard to read — omit
them in complex diagrams.

## Notes on choosing between flowchart / state / gantt

Default flowchart to `LR` (left→right), and switch to `TD` (top→down) only for deeply branching
diagrams. In stateDiagram-v2, always mark start and end explicitly with `[*]`.

```
stateDiagram-v2
  [*] --> Pending
  Pending --> Approved: approve
  Pending --> Rejected: reject
  Approved --> [*]
  Rejected --> [*]
```

Scope gantt to processes that actually have a dependency (`after`). Laying out independent parallel
tasks in gantt carries no more information than a table would — use a table in that case.

## A note on Japanese labels

Once a label exceeds 12 characters, mermaid's node width isn't computed automatically and the text
overflows. Insert a manual line break with `<br/>`.

```
A[First-pass review<br/>of the request]
```

Full-width parentheses `（）` pass through the parser unmolested inside a node label, but the
half-width symbols `[]` `{}` `()` collide with node-shape syntax and must not appear inside label
text. If you need them, wrap the whole label in double quotes.

```
A["Applying the coefficient (0.8)"]
```

## Syntax that tends to break

Nesting `subgraph` three levels or deeper breaks the layout engine and elements start overlapping.
Cap nesting at two levels; split anything that needs more.

```
subgraph Production
  subgraph Web tier
    A[Server 1]
    B[Server 2]
  end
end
```

Using Japanese characters or symbols (`-` `.` `/`) in a node ID causes a parse error. Keep IDs to
alphanumerics and underscores only, and put the Japanese text in the label.

```
web_1[Request intake server]   // Good: ID is alphanumeric, label is Japanese
申請サーバ1[Request intake]     // Bad: Japanese in the ID → parse error
```

A colon `:` collides with the edge-label delimiter — avoid it inside node labels, or quote it.

## Keeping .mmd files separate for reviewability

Cut one `.mmd` file per diagram, kept separate from the document body so it can be diff-reviewed.
Name the file an English slug describing the diagram's content, and place it in the same directory
as the document (e.g. `docs/report/flow-approval.mmd`). Committing the rendered SVG is fine, but
never delete the `.mmd` — otherwise every revision means hand-redrawing the SVG from scratch.

## Good and bad examples

A good diagram has alphanumeric participant/node IDs, Japanese labels, and a theme header matching
the document's tone. A bad diagram has any of the following:

- 4-level subgraph nesting with elements overlapping each other
- Node labels over 20 characters, overflowing without a `<br/>` break
- Three independent tasks forced into gantt as horizontal bars (a table would suffice)
- Pasted into the document still on the default purple theme (diagrams.md's theme header not applied)

## Self-check

- Does the diagram type (sequence/flow/state/gantt) match the axis you actually want to show?
- Are node IDs alphanumeric only, and are Japanese labels over 12 characters `<br/>`-wrapped?
- Is subgraph nesting capped at 2 levels?
- Is the `.mmd` kept alongside the document, with both it and the SVG committed?
- Does the theme header match the document's color scheme (see diagrams.md)?
