# Patterns for writing into Excel (per-cell)

Excel is a table, not a document, so Japanese text inside a cell follows different rules from
prose. Split a cell's role into three types (label / value / note) and keep each type's form.

## The three types

Label (header row, item name): noun phrase only, no period, aim for 8 characters or fewer.
> Good: "対応状況" (status), "完了予定日" (due date), "担当" (owner)
> Bad: "対応の状況について" (about the status), "いつ完了する予定か" (when is it expected to finish)

Value (data cell): noun-stop or a number + unit. One fact per cell, no period.
> Good: "対応済" (done), "2026-07-15", "3 件" (3 cases), "保留（仕様確認中）" (on hold, spec under review)
> Bad: "対応済みです。" (です ending), "7 月中旬ごろには完了する見込みとなっています" (rambling です/ます prose)

Note (remarks cell): at most two sentences. First sentence states the conclusion, second states the
condition. Use a period only when there are two sentences.
> Good: "API 側の修正待ち。7/15 リリースに同梱予定" (waiting on the API-side fix; scheduled to ship with the 7/15 release)
> Bad: "こちらについては先方の API 側の修正を待っている状況であり、それが終わり次第…" (rambling, unfinished)

## Forbidden inside a cell

Never cram multiple facts into one cell via line breaks (split into separate columns instead).
Never use です/ます. Never write process metadata ("(latest)", "(fixed)", "*was A before") — version
tracking belongs to the filename and an updated-date column. If you invent your own symbol legend
(◎○△×), always attach a legend cell — never let color alone carry the meaning.

## Fix the status vocabulary

Fix the set of status words used in a given column and never let it drift. Recommended set:
"未着手 / 対応中 / 対応済 / 保留 / 対象外" (not started / in progress / done / on hold / N/A). Never mix
"済", "完了", "done", and "対応した" within the same column.

## Numbers and dates

Enter numbers as a numeric type, and put the unit in the column header ("金額（万円）" — amount, in
¥10k). Never write "約" (approximately) inside a cell — if it's an estimate, state the basis in the
note column instead. Standardize dates as yyyy-mm-dd. Never write "7 月中" (sometime in July) or
"近日" (soon) into a value cell — for an unconfirmed date, use "未定" (TBD) plus a note.

## Designing for a single sheet

Fix the sheet to one purpose, and don't break the reading order (left → right for chronology, top →
bottom for priority). Once a sheet passes 12 columns, consider splitting it. Never use merged cells
— they break filtering and sorting.
