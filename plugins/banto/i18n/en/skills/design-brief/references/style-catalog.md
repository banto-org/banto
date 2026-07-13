# Visual style catalog (10 representative styles)

Visual style describes "how the look itself is built." The source article catalogs 27 styles; this
file summarizes the 10 that come up most often in practice. For the full catalog and detailed
feature tables, see the [source article](https://qiita.com/yusuke_ando_vj/items/dd17a285217a15841a3a)
(Japanese).

## The 10 representative styles

**Flat design**: a flat look with shadows and depth suppressed. Fits SaaS and admin dashboards, but
can be forgettable if decoration is stripped too far.

**Material design**: Google's approach of layering cards with shadows to express hierarchy. State
changes read clearly, but overuse makes a screen feel heavy.

**Glassmorphism**: frosted-glass, semi-transparent panels. Suits AI products and dashboards, but
legibility depends heavily on the background — text can become hard to read.

**Minimal design**: decoration stripped to a minimum, letting whitespace, type, and photography
carry the design. Fits brand sites and consulting, but gets harder to organize as content volume
grows.

**Neo-brutalism**: bold black outlines and vivid color for a pop, individual character. Fits indie
products and startup landing pages, but doesn't suit a premium feel.

**Editorial design**: magazine-style, with large headlines, large photography, and whitespace
driving the read. Fits media, travel, and beauty, but a high content volume hurts legibility — the
CTA needs deliberate handling.

**Dark UI**: a black or deep-navy background with white text. A default for AI and developer
tools, but long stretches of text on a dark background cause reading fatigue.

**Bento UI**: a grid mixing large and small cards to create visual emphasis. Fits SaaS and AI
product feature sections, but too many cards flattens the hierarchy into monotony.

**Modern Japanese (wa-modern)**: unbleached cream, ink black, and indigo, arranging traditional
Japanese elements in a contemporary way. Fits ryokan, craft, and heritage sites, but leaning too
far traditional reads as dated.

**Claymorphism**: soft, rounded, clay-like volume. Fits women's, children's, and wellness products,
but overuse reads as childish.

## Specifying combinations

Rather than specifying a single visual style, specify a base style with one accent style layered on
top — this communicates intent more precisely. Layering Bento UI's card structure on top of a
minimal base, for example, reads as "refined but organized," which suits a SaaS feature section.
Layering glassmorphism's translucent panels on top of a dark-UI base reads as "advanced and
futuristic," which suits AI or Web3 products. Cap combinations at two styles — stacking three or
more blurs the direction.
