# format-tables — Using Tables (Shared Across All Formats)

## First, Decide Whether It Should Be a Table

| Information | Format to use |
|---|---|
| Showing individual values precisely, for the reader to look up | Table |
| Showing a trend, pattern, or relative comparison | Chart (bar / line) |
| Cause and effect, reasoning, narrative | Prose |

Three or more items across two or more attributes calls for a table, not prose. If you're torn between a table and a chart, decide by asking "will the reader read individual numbers?" (Yes = table).

## Design Rules (Stephen Few-style evidence-based principles)

1. **Minimize gridlines**: no vertical gridlines as a rule. Horizontal gridlines only below the header and above the totals row. Create separation with whitespace instead
2. **Right-align numbers**, with thousands separators, and **put the unit in the column header** (cells hold only the number). Keep decimal places consistent within a column
3. **Limit significant digits**: show only as many digits as the comparison needs (roughly 2-3). Move precise values to an appendix
4. **Stack comparable values vertically**: arrange the table so the numbers the reader will compare line up in the same column
5. **Order columns by importance**: put the most important column on the left. Order rows logically (descending magnitude, chronological, alphabetical)
6. **Totals row goes at the bottom** (accounting convention). Emphasize with bold as the only attribute
7. **Use zebra striping cautiously**: only for tables with many rows and wide columns. If you use it, keep the contrast extremely subtle
8. **Keep headers short**: trim words rather than let a header wrap to two lines. Grouped headers go no deeper than one level

## Emphasis

Don't rely on color alone (accounts for color blindness and print). Combine bold, symbols (▲▼), and notes.
Use exactly one kind of emphasis per table. Emphasizing everything is the same as emphasizing nothing.

## Notes and Footnotes

Put sources, assumptions, and exceptions in small text directly under the table. Don't write long text inside a cell.

## Format-Specific Implementation

- **HTML**: always add `<th scope="col">`/`<th scope="row">` (for screen readers). Use `<caption>` or the immediately preceding heading for the caption
- **xlsx**: no merged cells. One data point per cell. Ship it with a filter applied
- **pptx**: a table on one slide should be at most roughly 5 rows × 4 columns. Split anything larger out into a handout (xlsx/docx)
- **docx**: place the table number (Table 1) and title **above the table** (the convention is captions below for figures, above for tables)
