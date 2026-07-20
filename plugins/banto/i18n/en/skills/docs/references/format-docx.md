# format-docx — Word Documents

A long-form format suited to printing, circulation, and formal record-keeping. Use it for approval requests, reports, procedure manuals, and contract-related documents.

## Document Structure

1. Cover page (title, date, addressee, sender, document number)
2. Table of contents (auto-generated from heading styles; required beyond 5 pages)
3. **Executive summary**: roughly 10% of the body length. Conclusion and key points come first. Write it last, after the body is finished
4. Body (heading hierarchy **up to 3 levels**)
5. Appendix (detailed data, precise figures, references)

## Style Features (no direct formatting)

- Always build headings with Word's heading styles (Heading 1/2/3). A "fake heading" made from bold text plus a larger font size is invisible to both the table of contents and screen readers
- Auto-generate the table of contents from styles. Number figures and tables via the insert-caption feature, and reference them from the body via cross-references
- When generating with python-docx, also use styles (e.g., Heading 1) — don't build headings from run-level direct formatting

## Typography

- Body text 10.5-12pt, line spacing 1.15-1.5 (theme default 1.3), margins sized to fit roughly 30-40 characters per line
- Follow the theme file for heading color and font

## Figures and Tables

- **Figure captions go below, table captions go above** (numbered as Figure 1 / Table 1)
- Always reference them from the body ("as shown in Figure 1..."). Delete any figure or table that isn't referenced
- Insert figures as SVG **converted to PNG** (same procedure and resolution as format-pptx.md)

## Japanese Business-Document Conventions

- External documents use the traditional opening/closing salutation pair (拝啓 / 敬具); internal documents omit them and instead use the "記／以上" memo-style format
- Official/public-facing writing follows the Agency for Cultural Affairs' guidelines for drafting official documents (公用文作成の考え方): roughly 50-60 characters per sentence, with commas marking semantic breaks

## Terminology Annotation

Default to a parenthetical definition at first use; use a footnote when the definition is too long to inline. For a document with more than 10 technical terms, attach a glossary at the end and point to it right after the executive summary.

## Sourcing

Cite external information via footnotes or an end-of-document reference list. Attach a footnote number at the point where a figure or study is cited. Internal information (in-house data, local files) needs no citation.

## Verification

1. Always open and check the generated file (converting to PDF via LibreOffice and reviewing every page image also works): heading hierarchy, page-number drift in the table of contents, missing figures, page-break positions. If no tool is available, read it back with python-docx to mechanically check styles and figure references, and note in the report that visual verification wasn't possible
2. Consistency between figure/table numbers and body references
3. Confirm styles were actually used (no headings built from direct formatting)
