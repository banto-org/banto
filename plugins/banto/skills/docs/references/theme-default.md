# theme-default — Default Theme (Japanese business standard, swappable)

> **How to swap it**: create `theme-custom.md` in the same references/ folder, in the same format as this file, and it
> takes precedence. Put a company's brand colors or an individual's preferences in
> theme-custom.md. Don't edit this file.

Design policy: an ivory background with white cards as the base, navy (blue-toned) as the primary
color. A composition built around "navy as the primary color" is a color scheme considered the
standard for conveying trust in Japanese business documents (MiriCanvas / Document Studio). The
ratio is 70:25:5 (base : primary : accent). Status colors use the actual values from the Color
Universal Design (CUD) recommended palette, 3rd edition, and every color used for text is
restricted to combinations with a pre-computed WCAG contrast ratio.

## Color tokens

| Token | Value | Meaning / use | Contrast against white |
|---|---|---|---|
| base-bg | `#FAF7F1` | Page background (ivory) | — |
| card-bg | `#FFFFFF` | Cards / body surface | — |
| ink | `#000000` | Body text (black) | 21.00:1 AAA (19.64:1 against ivory) |
| ink-soft | `#404040` | Supplementary text (dark black-toned gray) | 10.36:1 AAA (9.70:1 against ivory) |
| line | `#DDE1E6` | Rules / borders (decorative only — carries no meaning) | — |
| line-strong | `#C8C8CB` | Stronger divider (CUD achromatic, light gray) | — |
| accent | `#113160` | Primary (navy): headings, key UI, the lead color in diagrams | 12.87:1 AAA |
| accent-hover | `#0B3E8D` | Secondary navy (hover / links) | 10.06:1 AAA |
| accent-soft | `#E8EDF5` | Light navy tint (keybox / pill background; 10.95:1 with navy text) | — |
| accent-2 | `#FF9900` | Accent (CUD orange). **Shape fills, icons, and bands only — never for small text on a white background** (2.14:1) | 2.14:1 (unusable for text) |

## Status colors (CUD-compliant, split into 3 families by purpose)

Never rely on color alone: always pair it with an icon (✓ ✗ ⚠), a label word, and a border (a
core CUD rule).

| Status | ① For small text (dark shade) | ② For icons / large text / shapes (CUD accent) | ③ Light background (badges / fills, CUD base) | ④ Card light background (large areas, derived) |
|---|---|---|---|---|
| Success / good example | `#1D7A4E` (5.32:1, 4.98:1 against ivory) | `#35A16B` | `#87E7B0` (8.63:1 with navy text) | `#E9F6EF` |
| Problem / bad example | `#B32800` (6.52:1) | `#FF2800` | `#FFD1D1` (9.37:1 with navy text) | `#FFEFEF` |
| Warning / caution | `#8F4F00` (6.39:1) | `#FF9900` | `#FFFF99` (12.26:1 with navy text) | `#FFF6E5` |
| Info | `#0B3E8D` (10.06:1) | `#0041FF` | `#B4EBFA` (9.93:1 with navy text) | `#EFF7FB` |

- The ② CUD accent colors fall below 4.5:1 on a white background, so **never use them for small
  text** (green 3.25 / red 3.78 / yellow 1.16).
- ① is a text-safe dark shade derived using the Digital Agency method (when a brand color doesn't
  meet the contrast standard, adjust lightness while keeping the same hue).
- ④ is a light-background derivative in the same hue as ① and ③ (11.3:1 or higher with black
  text). The principle is to vary lightness rather than add more hues (Document Studio).

Principle: keep meaning and color fixed (success = green family, problem = red family — never
swap them). Keep the colors used in one deliverable within navy + the status family + achromatic
— don't introduce a new hue. Pair emphasis with a non-color attribute too (bold, an icon).

## Fonts

| Use | Spec |
|---|---|
| HTML | "Hiragino Kaku Gothic ProN","Hiragino Sans","Yu Gothic","Meiryo",system-ui,sans-serif (no web-font loading) |
| pptx | Noto Sans JP (fallback: Yu Gothic → Meiryo) |
| docx | Body = Yu Mincho or Yu Gothic, 10.5–12pt; headings = Yu Gothic |
| xlsx | Yu Gothic or Meiryo UI, 10–11pt |

## Format-specific mappings

- **HTML**: assign the tokens above directly to CSS variables (--bg, --accent, etc.).
- **pptx**: accent = RGB(17,49,96), accent-2 = RGB(255,153,0) (shapes/bands only). Title 28pt+/
  body 18pt+/margin notes 12pt. Use the ②/③ light backgrounds appropriately for projection; text
  stays navy or black.
- **docx**: Heading 1 = accent color, 16pt bold; Heading 2 = 14pt bold; body = black (#000000).
  Line spacing 1.3.
- **xlsx**: header row = accent background `#113160` with white text (12.87:1); input cells =
  blue text `#0B3E8D`; calculated cells = black text; cross-sheet references = green text
  `#1D7A4E` (financial-modeling convention + text-safe dark shade).

## Diagram (SVG) colors

Keep the color tokens used in diagrams built with the diagram skill identical to this table
(correct/mitigation = green family ①④, problem = red family ①④, primary/flow = navy, emphasis =
orange ② in small areas only). If you create theme-custom.md, define the diagram colors there too.

## Sources (summary)

- White × navy as the standard, the 3-color rule, 70:25:5: MiriCanvas "PowerPoint color schemes"
  / Document Studio "Color schemes for PowerPoint materials"
- CUD recommended palette 3rd-edition actual values: University of Tokyo distributed data
  (confirmed via the Kawasaki City official-document guidelines)
- Contrast standard: WCAG 2.1 SC 1.4.3 (4.5:1 / 3:1 for large text) / Digital Agency design
  system (always 4.5:1, without using the large-text relaxation)
- Full verification of all values: `{base}/docs/research/2026-07-20_jp-business-color-palette.md`
  (18 pairs + derived-color calculation record)
