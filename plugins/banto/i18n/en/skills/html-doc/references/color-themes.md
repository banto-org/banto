# Color Themes — 7 themes (light mode only, WCAG AA compliant)

All 7 themes ship bundled with every template. Switch between them just by rewriting `<html data-theme="...">`.
The default is `claude` (ivory ground + white cards + terracotta accent). Contrast ratios are designed so that body text against white cards / light fills meets WCAG AA.

## How to switch

```html
<html lang="ja" data-theme="claude">     <!-- just change this -->
```

## Variable model (v2)

Each theme is composed of the following CSS variables (already defined in each template's `:root, html[data-theme="..."]` block):

| Variable | Role |
|---|---|
| `--bg` | Page ground (off-white to a faint tint) |
| `--surface` | Surface color for cards/tables/appendices (basically pure white `#fff`) |
| `--wash` | Light fill (callout background, table header, inline code, bar background) |
| `--ink` / `--sub` | Body text / secondary text |
| `--accent` / `--accent-deep` | Accent / deep accent (links, heading numbers, emphasis) |
| `--accent-soft` | An extremely light fill of the accent (badges, STEP pills, selection ranges) |
| `--hairline` | Rule lines / card borders |
| `--shadow` | Card shadow (removed at print time) |
| `--serif` | Serif font stack for headings |

Status colors are shared across all themes (theme-independent, badges/callouts only):
`--ok #1A7F4B` / `--ok-bg #E5F3EB` , `--warn #955F00` / `--warn-bg #FAF0D9` , `--bad #B3261E` / `--bad-bg #F9E8E7`.

## Theme list

| theme | accent | accent-deep | bg | surface | Best suited for |
|---|---|---|---|---|---|
| `claude` terracotta (**default**) | `#D97757` | `#AE5630` | `#F0EEE6` | `#FFFFFF` | General purpose, warm tone, works for both internal and external audiences |
| `navy` navy blue | `#2D5986` | `#1A3A5C` | `#F2F4F7` | `#FFFFFF` | Reports, finance, consulting |
| `forest` deep green | `#2D7A4A` | `#1A4D2E` | `#F1F5F1` | `#FFFFFF` | Environmental, healthcare, sustainability reports |
| `burgundy` burgundy | `#9B2D45` | `#6B1A2E` | `#F6F1F1` | `#FFFFFF` | Traditional industries, culture, legal |
| `sumi` ink black | `#444` | `#2B2B2B` | `#F4F4F2` | `#FFFFFF` | Specifications, academic, minimal annual reports |
| `copper` copper | `#A85230` | `#7A3B1E` | `#F7F3EE` | `#FFFFFF` | Creative, architecture, craft |
| `slate` slate | `#4A6278` | `#2C3E50` | `#F2F4F6` | `#FFFFFF` | IT, SaaS, technical proposals |

## How to choose

1. If the user specifies one, use it.
2. If the client has a brand color, use a custom theme (below).
3. If unspecified, choose from the table above based on the document's character and disclose it as an adopted interpretation (**when in doubt, default to `claude`**).

## Custom theme (client brand color)

Derive the theme from a single brand color. Append an `html[data-theme="custom"]` block to the template's `:root` block and set `data-theme="custom"`:

```css
html[data-theme="custom"] {
  --bg:#…;          /* an off-white containing just a trace of accent (around 97% lightness) */
  --surface:#fff;   /* keep this pure white by default */
  --wash:#…;        /* accent diluted to about 90% white (light fill) */
  --ink:#1F1E1D; --sub:#63605A;   /* body-text colors can stay as-is */
  --accent:#…;      /* brand color. At least 3:1 contrast against white (for fills/shapes) */
  --accent-deep:#…; /* a darker shade of the same hue. At least 4.5:1 against white (for text/links) */
  --accent-soft:#…; /* accent diluted to about 85% white (badge background) */
  --hairline:#…;    /* accent diluted to about 78% white (rule lines) */
  --shadow:0 1px 2px rgba(0,0,0,.05), 0 4px 16px rgba(0,0,0,.07);
  --serif:Georgia,"Hiragino Mincho ProN",serif;
}
```

Verification: confirm that body text `--ink` against `--surface`/`--bg`, and `--accent-deep` against white, meet WCAG AA (4.5:1).

## Prohibited

- Adding a second accent color (the three status colors are an exception).
- System blue (`#007bff` / `#0d6efd` family) — the hallmark of a Bootstrap/AI-template look.
- Dark mode support (this skill is light mode only).
- Embedding mermaid diagrams with their default purple left as-is (align to wash/hairline via the theme header in diagrams.md).
