# format-xlsx — Excel Documents

A format for checking, reusing, and re-sorting numbers. Build anything meant to be "read" in HTML or docx instead — don't use Excel as a document-layout tool.

## Sheet Structure

1. **One sheet, one purpose**. Put a "cover/README" sheet first (purpose, sheet list, legend, last-updated date, author)
2. Give sheets short, descriptive names. Order them in the sequence the reader will work through them
3. For large datasets, separate a "data" sheet from a "summary/display" sheet

## Layout

- **Don't start at A1**: leave column A and row 1 empty, starting content at B2 (the margin acts as a frame)
- Always set frozen panes (header row, key column)
- Hide gridlines and draw only the borders you need
- Size columns to fit their content; header rows use the theme's accent color with white text

## Color Convention (financial-modeling practice)

| Color | Meaning |
|---|---|
| Blue text | Manually entered value (hardcoded) |
| Black text | A formula referencing the same sheet |
| Green text | A reference to another sheet |
| Red text | An external link / needs attention |

Write this convention, with the reasoning, in the cover sheet's legend (assume the reader doesn't already know it).

## Number Formatting

- Round only the display, never the underlying value: thousands `#,##0,`, millions `#,##0,,`
- Negative numbers use accounting-style parentheses `(1,234)`; standardize dates on ISO format (YYYY-MM-DD)
- Percentages to one decimal place

## Prohibiting the "Graph-Paper Excel" Antipattern

No merged cells, one data point per cell, no positioning content with line breaks or spaces (per the Ministry of Internal Affairs and Communications' guidelines on machine-readable data notation). Even for print layouts, use "center across selection" instead of merging cells.

## Diagrams

Insert SVGs **converted to PNG** (300dpi-equivalent, transparent; same conversion procedure as format-pptx.md). After inserting, check for overlap with cells and any scaling distortion.

## Terminology Annotation

Use an annotation column or a cell comment for technical terms. Collect frequently used terms into a "Glossary" sheet and reference it from the cover sheet.

## Pre-Delivery Checklist

1. Save with cell A1 selected on every sheet (so the top of the sheet is visible on open)
2. Save with the first sheet (cover) as the active/displayed sheet
3. Standardize zoom at 100%
4. Print range and page setup (if the file may be printed)
5. Zero formula errors (#REF! etc.), zero broken external links
6. If generated with openpyxl, actually open it in Excel/LibreOffice to check the display. In an environment where that's not possible, read it back with openpyxl to mechanically check values, formatting, and formula errors, and note in the report that visual verification wasn't possible
