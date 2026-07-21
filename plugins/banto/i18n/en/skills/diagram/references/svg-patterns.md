# SVG Pattern Library — Complete Code for 14 Patterns

A library of working code for explanatory diagrams. Once you pick a pattern, copy the code and swap
in your own text, colors, and coordinates. If the text length changes, change the rect's width too
(overflow is the single biggest cause of "broken" layouts).

## Common specification (all patterns)

- Fix `viewBox="0 0 624 <height>"`. Do not set `width` / `height` attributes (make it responsive on
  the CSS side with `max-width:100%; height:auto`).
- Always include `role="img"` + `aria-label` (one sentence describing the diagram's content).
- Align coordinates to an 8px grid. Standardize box height to one of 40 / 48 / 56px, and vary only
  the width by content.
- **Box width = max label character count × 13px + 24px padding** as the minimum width, rounded up
  to a multiple of 8 (example: 7 full-width characters → 7×13+24=115 → 120px).
- Text must be 11px or larger (body labels 12–13px / headings 13–14px / captions 11–11.5px). Under
  11px is forbidden.
- Wrap labels only with manual `tspan` line breaks (SVG's `<text>` does not auto-wrap — don't rely
  on automatic wrapping).
- Define exactly one arrow style per diagram inside `<defs><marker>` and reuse it (keep the `id`
  unique within the diagram).
- When a pattern's element count or character count exceeds the limits given in its "Constraints"
  line, split the diagram per the splitting guidance at the end of that section.

Common arrow marker:

```svg
<defs><marker id="ah" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0,0L10,5L0,10z" fill="#113160"/></marker></defs>
```

## Color tokens (navy-based; meaning and color are fixed)

| Meaning | Wash | Border | Text |
|---|---|---|---|
| Primary / flow / emphasis frame | `#E8EDF5` | `#C9D6E8` | `#113160` (dark navy; also used as fill) |
| Correct / solution / After | `#E9F6EF` | `#87E7B0` | `#1D7A4E` |
| Problem / bad example / Before | `#FFEFEF` | `#FFD1D1` | `#B32800` |
| Neutral / foundation | `#F0F2F5` | `#DDE1E6` | `#5A6472` |
| Supporting (blue / informational) | `#A8C5E8` | — | `#0B3E8D` |
| Warning / emphasis accent | shapes only `#FF9900` | — | text uses `#8F4F00` (never use `#FF9900` for text) |

Navy gradient series (for expressing stages in rankings / funnels): `#113160` → `#1B3E70` →
`#40699F` → `#7595BE` → `#A8BCD9` → `#C9D6E8`.
Use at most 4 color families in a single diagram. Correct is always green-toned, problems are always
red-toned — fixed, never swapped.

---

## ① Correspondence Mapping

Structure conveyed: A one-to-one correspondence between two lists (problem → solution, requirement
→ feature, role → owner).
Constraints: up to 4 pairs / box label up to 13 full-width characters per line, 2 lines max /
viewBox 624×288 (height +64 for each additional pair).

```svg
<svg viewBox="0 0 624 288" role="img" aria-label="3つの問題と3つの対策が1対1で対応する図">
  <defs><marker id="p01" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0,0L10,5L0,10z" fill="#113160"/></marker></defs>
  <text x="144" y="28" font-size="14" font-weight="700" text-anchor="middle" fill="#B32800">問題</text>
  <text x="480" y="28" font-size="14" font-weight="700" text-anchor="middle" fill="#113160">対策</text>
  <rect x="32" y="40" width="224" height="48" rx="8" fill="#FFEFEF" stroke="#FFD1D1"/>
  <text x="144" y="60" font-size="13" text-anchor="middle" fill="#B32800"><tspan x="144">① 中身の薄い決まり文句</tspan><tspan x="144" dy="17" font-size="11.5">「〜を最適化」「〜を実現」</tspan></text>
  <rect x="32" y="104" width="224" height="48" rx="8" fill="#FFEFEF" stroke="#FFD1D1"/>
  <text x="144" y="124" font-size="13" text-anchor="middle" fill="#B32800"><tspan x="144">② 未定義・誤展開の略語</tspan><tspan x="144" dy="17" font-size="11.5">「BP」「2FA」をいきなり使う</tspan></text>
  <rect x="32" y="168" width="224" height="48" rx="8" fill="#FFEFEF" stroke="#FFD1D1"/>
  <text x="144" y="188" font-size="13" text-anchor="middle" fill="#B32800"><tspan x="144">③ 単独で読めない文</tspan><tspan x="144" dy="17" font-size="11.5">「これ」「それ」の指す先が不明</tspan></text>
  <rect x="368" y="40" width="224" height="48" rx="8" fill="#E9F6EF" stroke="#87E7B0"/>
  <text x="480" y="60" font-size="13" text-anchor="middle" fill="#1D7A4E"><tspan x="480">具体的な動作・数値に置換</tspan><tspan x="480" dy="17" font-size="11.5" fill="#113160">「月6時間短縮する」</tspan></text>
  <rect x="368" y="104" width="224" height="48" rx="8" fill="#E9F6EF" stroke="#87E7B0"/>
  <text x="480" y="124" font-size="13" text-anchor="middle" fill="#1D7A4E"><tspan x="480">初出で定義 ＋ 用語集</tspan><tspan x="480" dy="17" font-size="11.5" fill="#113160">「二要素認証（2FA）」</tspan></text>
  <rect x="368" y="168" width="224" height="48" rx="8" fill="#E9F6EF" stroke="#87E7B0"/>
  <text x="480" y="188" font-size="13" text-anchor="middle" fill="#1D7A4E"><tspan x="480">一文を自己完結させる</tspan><tspan x="480" dy="17" font-size="11.5" fill="#113160">主語と対象を文の中に明示</tspan></text>
  <line x1="260" y1="64" x2="364" y2="64" stroke="#113160" stroke-width="2" marker-end="url(#p01)"/>
  <line x1="260" y1="128" x2="364" y2="128" stroke="#113160" stroke-width="2" marker-end="url(#p01)"/>
  <line x1="260" y1="192" x2="364" y2="192" stroke="#113160" stroke-width="2" marker-end="url(#p01)"/>
  <rect x="32" y="232" width="560" height="40" rx="8" fill="#F0F2F5" stroke="#DDE1E6"/>
  <text x="312" y="257" font-size="13" text-anchor="middle" fill="#5A6472">共通の土台：スタイルガイド ＋ 公開前の人手レビュー</text>
</svg>
```

When exceeding the limit: if there are more than 5 pairs, split into two diagrams by theme (don't
cram them into one).

## ② Comparison Split (✗/✓) — including Before/After and cause-effect contrasts

Structure conveyed: A left-right contrast between a good and a bad approach. For Before→After or
cause→effect contrasts, the center arrow shows the direction of time or causality (place the
important / positive side on the right).
Constraints: up to 3 items per panel / panel heading up to 12 full-width characters / item label up
to 16 full-width characters per line, 2 lines max / viewBox 624×240.

```svg
<svg viewBox="0 0 624 240" role="img" aria-label="手作業リリースと自動化後のリリースの対比図">
  <defs><marker id="p02" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0,0L10,5L0,10z" fill="#113160"/></marker></defs>
  <rect x="16" y="16" width="272" height="208" rx="10" fill="#FFEFEF" stroke="#FFD1D1"/>
  <text x="32" y="44" font-size="13" font-weight="700" fill="#B32800">✗ 手作業のリリース</text>
  <rect x="32" y="64" width="240" height="40" rx="8" fill="#fff" stroke="#FFD1D1"/>
  <text x="152" y="89" font-size="12" text-anchor="middle" fill="#B32800">手順書を目で追って実行</text>
  <rect x="32" y="112" width="240" height="40" rx="8" fill="#fff" stroke="#FFD1D1"/>
  <text x="152" y="137" font-size="12" text-anchor="middle" fill="#B32800">深夜の待機が常態化</text>
  <rect x="32" y="160" width="240" height="40" rx="8" fill="#fff" stroke="#FFD1D1"/>
  <text x="152" y="175" font-size="12" text-anchor="middle" fill="#B32800"><tspan x="152">環境ごとに設定を</tspan><tspan x="152" dy="16">手で書き換える</tspan></text>
  <line x1="292" y1="120" x2="326" y2="120" stroke="#113160" stroke-width="2" marker-end="url(#p02)"/>
  <rect x="336" y="16" width="272" height="208" rx="10" fill="#E9F6EF" stroke="#87E7B0"/>
  <text x="352" y="44" font-size="13" font-weight="700" fill="#1D7A4E">✓ 自動化後のリリース</text>
  <rect x="352" y="64" width="240" height="40" rx="8" fill="#fff" stroke="#87E7B0"/>
  <text x="472" y="89" font-size="12" text-anchor="middle" fill="#1D7A4E">パイプラインが手順を実行</text>
  <rect x="352" y="112" width="240" height="40" rx="8" fill="#fff" stroke="#87E7B0"/>
  <text x="472" y="137" font-size="12" text-anchor="middle" fill="#1D7A4E">日中の定時リリース</text>
  <rect x="352" y="160" width="240" height="40" rx="8" fill="#fff" stroke="#87E7B0"/>
  <text x="472" y="185" font-size="12" text-anchor="middle" fill="#1D7A4E">設定はコードで一元管理</text>
</svg>
```

When exceeding the limit: if there are more than 4 items, narrow the focus down to 3, or split into
two diagrams by viewpoint.

## ③ Capacity Stack

Structure conveyed: A finite capacity and how its composition changes. The dashed frame = capacity,
the colored blocks = breakdown. A left-right comparison shows "cutting something frees up room."
Constraints: up to 3 stacked blocks / block label up to 11 full-width characters per line, 2 lines
max / viewBox 624×264.

```svg
<svg viewBox="0 0 624 264" role="img" aria-label="認知負荷の内訳：悪い資料と良い資料の比較図">
  <defs><marker id="p03" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0,0L10,5L0,10z" fill="#5A6472"/></marker></defs>
  <text x="152" y="28" font-size="14" font-weight="700" text-anchor="middle" fill="#B32800">✗ 悪い資料</text>
  <text x="472" y="28" font-size="14" font-weight="700" text-anchor="middle" fill="#113160">✓ 良い資料</text>
  <rect x="48" y="40" width="208" height="184" rx="12" fill="none" stroke="#7F878F" stroke-width="2" stroke-dasharray="6 4"/>
  <text x="152" y="248" font-size="12" text-anchor="middle" fill="#5A6472">ワーキングメモリ（容量 4±1）</text>
  <rect x="64" y="56" width="176" height="56" rx="7" fill="#A8C5E8"/>
  <text x="152" y="89" font-size="13" text-anchor="middle" fill="#14273E">内容の難しさ（内在的）</text>
  <rect x="64" y="120" width="176" height="88" rx="7" fill="#FFB84D"/>
  <text x="152" y="158" font-size="13" text-anchor="middle" fill="#8F4F00"><tspan x="152">伝え方の悪さ（外在的）</tspan><tspan x="152" dy="18" font-size="11.5">長文・散らばり・未定義語</tspan></text>
  <line x1="264" y1="132" x2="352" y2="132" stroke="#5A6472" stroke-width="2" marker-end="url(#p03)"/>
  <text x="308" y="118" font-size="12" text-anchor="middle" fill="#5A6472">外在的負荷を削る</text>
  <rect x="368" y="40" width="208" height="184" rx="12" fill="none" stroke="#7F878F" stroke-width="2" stroke-dasharray="6 4"/>
  <text x="472" y="248" font-size="12" text-anchor="middle" fill="#5A6472">ワーキングメモリ（容量 4±1）</text>
  <rect x="384" y="56" width="176" height="56" rx="7" fill="#A8C5E8"/>
  <text x="472" y="89" font-size="13" text-anchor="middle" fill="#14273E">内容の難しさ（内在的）</text>
  <rect x="384" y="120" width="176" height="32" rx="7" fill="#FFB84D"/>
  <text x="472" y="140" font-size="12" text-anchor="middle" fill="#8F4F00">外在的（最小化）</text>
  <rect x="384" y="160" width="176" height="48" rx="7" fill="#E9F6EF" stroke="#87E7B0"/>
  <text x="472" y="180" font-size="12" text-anchor="middle" fill="#1D7A4E"><tspan x="472">空いた容量 →</tspan><tspan x="472" dy="16">内容の理解に使える</tspan></text>
</svg>
```

When exceeding the limit: if the breakdown exceeds 4 tiers, bundle the rest into "Other" and bring
it down to 3 tiers (this pattern shows a rough composition — leave exact ratios to a chart).

## ④ Flowchart / Process Chart

Structure conveyed: The flow of a procedure or process — a straight-line main flow plus at most one
return branch. Switch to mermaid's `flowchart` for strict flows with many decision branches.
Constraints: up to 5 steps in series / box label up to 7 full-width characters per line, 2 lines
max / at most one return branch / viewBox 624×208.

```svg
<svg viewBox="0 0 624 208" role="img" aria-label="申請から公開までの4ステップと差戻しの流れ図">
  <defs><marker id="p04" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0,0L10,5L0,10z" fill="#113160"/></marker></defs>
  <rect x="24" y="48" width="120" height="56" rx="8" fill="#E8EDF5" stroke="#C9D6E8"/>
  <text x="84" y="81" font-size="13" text-anchor="middle" fill="#113160">申請受付</text>
  <rect x="176" y="48" width="120" height="56" rx="8" fill="#E8EDF5" stroke="#C9D6E8"/>
  <text x="236" y="81" font-size="13" text-anchor="middle" fill="#113160">内容確認</text>
  <rect x="328" y="48" width="120" height="56" rx="8" fill="#E8EDF5" stroke="#C9D6E8"/>
  <text x="388" y="73" font-size="13" text-anchor="middle" fill="#113160"><tspan x="388">承認者の</tspan><tspan x="388" dy="17">最終判定</tspan></text>
  <rect x="480" y="48" width="120" height="56" rx="8" fill="#E9F6EF" stroke="#87E7B0"/>
  <text x="540" y="81" font-size="13" text-anchor="middle" fill="#1D7A4E">公開</text>
  <line x1="148" y1="76" x2="172" y2="76" stroke="#113160" stroke-width="2" marker-end="url(#p04)"/>
  <line x1="300" y1="76" x2="324" y2="76" stroke="#113160" stroke-width="2" marker-end="url(#p04)"/>
  <line x1="452" y1="76" x2="476" y2="76" stroke="#113160" stroke-width="2" marker-end="url(#p04)"/>
  <rect x="328" y="136" width="120" height="40" rx="8" fill="#F0F2F5" stroke="#DDE1E6"/>
  <text x="388" y="161" font-size="12" text-anchor="middle" fill="#5A6472">差戻し（不備）</text>
  <line x1="388" y1="108" x2="388" y2="130" stroke="#113160" stroke-width="1.5" stroke-dasharray="4 3" marker-end="url(#p04)"/>
  <path d="M324,156 H236 V112" fill="none" stroke="#113160" stroke-width="1.5" stroke-dasharray="4 3" marker-end="url(#p04)"/>
</svg>
```

When exceeding the limit: if there are more than 6 steps, or 2 or more decision branches, switch to
mermaid's `flowchart LR` (automatic layout is less prone to breaking).

## ⑤ Ranking Bar

Structure conveyed: Ordering / magnitude. Bars are stacked top-to-bottom in rank order, with length
representing strength. Place labels directly to the right of each bar (never as a separate legend).
Constraints: up to 6 items / label up to 14 full-width characters per line, 2 lines max / viewBox
624×256.

```svg
<svg viewBox="0 0 624 256" role="img" aria-label="視覚エンコーディングの知覚精度ランキングの横棒図">
  <g font-size="13" fill="#333333">
    <rect x="24" y="16" width="336" height="24" rx="5" fill="#113160"/><text x="368" y="33">共通の軸の上の位置 ― 最も正確</text>
    <rect x="24" y="56" width="288" height="24" rx="5" fill="#1B3E70"/><text x="320" y="73">別々の軸の上の位置</text>
    <rect x="24" y="96" width="240" height="24" rx="5" fill="#40699F"/><text x="272" y="113">長さ・方向・角度</text>
    <rect x="24" y="136" width="184" height="24" rx="5" fill="#7595BE"/><text x="216" y="153">面積</text>
    <rect x="24" y="176" width="136" height="24" rx="5" fill="#A8BCD9"/><text x="168" y="193">体積・曲率</text>
    <rect x="24" y="216" width="88" height="24" rx="5" fill="#C9D6E8"/><text x="120" y="224" font-size="11.5" fill="#5A6472"><tspan x="120">色の濃淡</tspan><tspan x="120" dy="14">― 最も不正確</tspan></text>
  </g>
</svg>
```

When exceeding the limit: if there are more than 7 items, round down to the top 5 + "Other," or
switch to a real chart library if the numbers themselves are the point.

## ⑥ Pyramid Structure

Structure conveyed: A persuasive structure that places the conclusion at the apex and arranges
supporting evidence in layers below it (use Logic Tree ⑦ instead when the goal is decomposition or
discovery).
Constraints: up to 3–4 layers / layer label up to 13 full-width characters per line, 2 lines max /
viewBox 624×272.

```svg
<svg viewBox="0 0 624 272" role="img" aria-label="ピラミッド原則：結論・根拠・データの3層構造図">
  <defs><marker id="p06" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0,0L10,5L0,10z" fill="#5A6472"/></marker></defs>
  <polygon points="312,24 400,96 224,96" fill="#113160"/>
  <polygon points="224,104 400,104 448,176 176,176" fill="#2A4F86"/>
  <polygon points="176,184 448,184 496,256 128,256" fill="#8FA9CC"/>
  <text x="312" y="76" fill="#fff" font-size="14" font-weight="700" text-anchor="middle">結論（主張）</text>
  <text x="312" y="138" fill="#fff" font-size="13" text-anchor="middle"><tspan x="312">根拠のグループ</tspan><tspan x="312" dy="17" font-size="11.5">（2〜3個・重複と漏れなく）</tspan></text>
  <text x="312" y="226" fill="#14273E" font-size="13" text-anchor="middle">個々のデータ・事実</text>
  <line x1="56" y1="248" x2="56" y2="48" stroke="#5A6472" stroke-width="1.6" marker-end="url(#p06)"/>
  <text x="56" y="32" font-size="12" fill="#5A6472" text-anchor="middle">考える順</text>
  <text x="56" y="266" font-size="11" fill="#5A6472" text-anchor="middle">（下から上へ）</text>
  <line x1="568" y1="48" x2="568" y2="248" stroke="#5A6472" stroke-width="1.6" marker-end="url(#p06)"/>
  <text x="568" y="32" font-size="12" fill="#5A6472" text-anchor="middle">伝える順</text>
  <text x="568" y="266" font-size="11" fill="#5A6472" text-anchor="middle">（上から下へ）</text>
</svg>
```

When exceeding the limit: 5 or more layers make each layer's label unreadable. Consolidate layers
down to 4 or fewer, or move the lower layer's detail into a separate Logic Tree ⑦ diagram.

## ⑦ Logic Tree

Structure conveyed: Decomposition / hierarchy (parent-to-child branching, mutually exclusive and
collectively exhaustive). Used for problem analysis and covering the full space of countermeasures
(use Pyramid ⑥ when the goal is persuasion).
Constraints: up to 3 levels / 3–4 children, 2–3 grandchildren each (12 elements total max) / child
label up to 8 full-width characters, grandchild label up to 12 full-width characters (2 lines max
each) / viewBox 624×312.

```svg
<svg viewBox="0 0 624 312" role="img" aria-label="売上拡大を3つの打ち手に分解するロジックツリー">
  <rect x="24" y="132" width="128" height="48" rx="8" fill="#113160"/>
  <text x="88" y="161" font-size="13" font-weight="700" text-anchor="middle" fill="#fff">売上拡大</text>
  <rect x="216" y="36" width="136" height="48" rx="8" fill="#E8EDF5" stroke="#C9D6E8"/>
  <text x="284" y="65" font-size="13" text-anchor="middle" fill="#113160">客数を増やす</text>
  <rect x="216" y="132" width="136" height="48" rx="8" fill="#E8EDF5" stroke="#C9D6E8"/>
  <text x="284" y="161" font-size="13" text-anchor="middle" fill="#113160">客単価を上げる</text>
  <rect x="216" y="228" width="136" height="48" rx="8" fill="#E8EDF5" stroke="#C9D6E8"/>
  <text x="284" y="257" font-size="13" text-anchor="middle" fill="#113160">頻度を上げる</text>
  <rect x="408" y="16" width="192" height="40" rx="8" fill="#fff" stroke="#DDE1E6"/>
  <text x="504" y="41" font-size="12" text-anchor="middle" fill="#333333">新規チャネルの開拓</text>
  <rect x="408" y="64" width="192" height="40" rx="8" fill="#fff" stroke="#DDE1E6"/>
  <text x="504" y="89" font-size="12" text-anchor="middle" fill="#333333">既存客の紹介促進</text>
  <rect x="408" y="112" width="192" height="40" rx="8" fill="#fff" stroke="#DDE1E6"/>
  <text x="504" y="137" font-size="12" text-anchor="middle" fill="#333333">セット販売の導入</text>
  <rect x="408" y="160" width="192" height="40" rx="8" fill="#fff" stroke="#DDE1E6"/>
  <text x="504" y="185" font-size="12" text-anchor="middle" fill="#333333">上位プランの提案</text>
  <rect x="408" y="208" width="192" height="40" rx="8" fill="#fff" stroke="#DDE1E6"/>
  <text x="504" y="233" font-size="12" text-anchor="middle" fill="#333333">定期購入の導入</text>
  <rect x="408" y="256" width="192" height="40" rx="8" fill="#fff" stroke="#DDE1E6"/>
  <text x="504" y="272" font-size="11.5" text-anchor="middle" fill="#333333"><tspan x="504">休眠顧客への</tspan><tspan x="504" dy="15">再訪クーポン配信</tspan></text>
  <g fill="none" stroke="#A8C5E8" stroke-width="1.5">
    <path d="M152,156 H184 V60 H216"/>
    <path d="M152,156 H184 V156 H216"/>
    <path d="M152,156 H184 V252 H216"/>
    <path d="M352,60 H380 V36 H408"/>
    <path d="M352,60 H380 V84 H408"/>
    <path d="M352,156 H380 V132 H408"/>
    <path d="M352,156 H380 V180 H408"/>
    <path d="M352,252 H380 V228 H408"/>
    <path d="M352,252 H380 V276 H408"/>
  </g>
</svg>
```

When exceeding the limit: if there are more than 12 elements, split the diagram by branch (the first
diagram = root + children, subsequent diagrams = a sub-tree rooted at each child).

## ⑧ 2-Axis Matrix (2×2 Matrix — Four Quadrants)

Structure conveyed: Positioning / prioritization along two axes (for forward-looking strategy — use
a scatter plot for the distribution of existing data).
Constraints: up to 2 elements per quadrant / quadrant name up to 8 full-width characters / element
label up to 8 full-width characters, 2 lines max / viewBox 624×424.

```svg
<svg viewBox="0 0 624 424" role="img" aria-label="市場成長率と利益率の2軸で事業を4象限に分類する図">
  <rect x="104" y="48" width="224" height="160" fill="#F0F2F5"/>
  <rect x="328" y="48" width="224" height="160" fill="#E8EDF5"/>
  <rect x="104" y="208" width="224" height="160" fill="#F0F2F5"/>
  <rect x="328" y="208" width="224" height="160" fill="#F0F2F5"/>
  <rect x="104" y="48" width="448" height="320" fill="none" stroke="#DDE1E6"/>
  <line x1="328" y1="48" x2="328" y2="368" stroke="#fff" stroke-width="3"/>
  <line x1="104" y1="208" x2="552" y2="208" stroke="#fff" stroke-width="3"/>
  <text x="104" y="36" font-size="12" font-weight="700" fill="#5A6472">↑ 市場成長率</text>
  <text x="552" y="392" font-size="12" font-weight="700" text-anchor="end" fill="#5A6472">利益率 →</text>
  <text x="120" y="72" font-size="12" font-weight="700" fill="#5A6472">育成</text>
  <text x="344" y="72" font-size="12" font-weight="700" fill="#113160">重点投資</text>
  <text x="120" y="232" font-size="12" font-weight="700" fill="#5A6472">撤退検討</text>
  <text x="344" y="232" font-size="12" font-weight="700" fill="#5A6472">維持</text>
  <rect x="360" y="96" width="128" height="40" rx="8" fill="#fff" stroke="#C9D6E8"/>
  <text x="424" y="121" font-size="12" text-anchor="middle" fill="#113160">クラウド事業</text>
  <rect x="400" y="152" width="128" height="40" rx="8" fill="#fff" stroke="#C9D6E8"/>
  <text x="464" y="177" font-size="12" text-anchor="middle" fill="#113160">API 連携基盤</text>
  <rect x="136" y="112" width="128" height="40" rx="8" fill="#fff" stroke="#DDE1E6"/>
  <text x="200" y="137" font-size="12" text-anchor="middle" fill="#5A6472">新規メディア</text>
  <rect x="392" y="264" width="128" height="40" rx="8" fill="#fff" stroke="#DDE1E6"/>
  <text x="456" y="289" font-size="12" text-anchor="middle" fill="#5A6472">受託開発</text>
  <rect x="144" y="288" width="128" height="40" rx="8" fill="#fff" stroke="#DDE1E6"/>
  <text x="208" y="304" font-size="11.5" text-anchor="middle" fill="#5A6472"><tspan x="208">レガシー製品の</tspan><tspan x="208" dy="15">保守販売</tspan></text>
</svg>
```

When exceeding the limit: if there are more than 9 elements, revisit the axis definitions and narrow
the scope (this pattern is for selection, not for listing every item).

## ⑨ Venn Diagram (2–3 sets)

Structure conveyed: Overlap and commonality between sets (e.g., expressing a framework such as 3C
analysis). Show intersections with overlapping shades of a single color (don't overlap multiple
colors — it muddies the result).
Constraints: up to 3 sets / circle label up to 6 full-width characters, 2 lines max / up to 2
intersection labels, 6 full-width characters / viewBox 624×448. For 2 sets, place two circles
symmetrically left-right and shrink the height to 336.

```svg
<svg viewBox="0 0 624 448" role="img" aria-label="自社・競合・顧客の3円が重なるベン図">
  <circle cx="240" cy="176" r="112" fill="#113160" fill-opacity="0.10" stroke="#113160" stroke-opacity="0.35" stroke-width="1.5"/>
  <circle cx="384" cy="176" r="112" fill="#113160" fill-opacity="0.10" stroke="#113160" stroke-opacity="0.35" stroke-width="1.5"/>
  <circle cx="312" cy="304" r="112" fill="#113160" fill-opacity="0.10" stroke="#113160" stroke-opacity="0.35" stroke-width="1.5"/>
  <text x="208" y="112" font-size="13" font-weight="700" text-anchor="middle" fill="#113160"><tspan x="208">自社</tspan><tspan x="208" dy="16" font-size="11.5" font-weight="400">Company</tspan></text>
  <text x="416" y="112" font-size="13" font-weight="700" text-anchor="middle" fill="#113160"><tspan x="416">競合</tspan><tspan x="416" dy="16" font-size="11.5" font-weight="400">Competitor</tspan></text>
  <text x="312" y="392" font-size="13" font-weight="700" text-anchor="middle" fill="#113160"><tspan x="312">顧客</tspan><tspan x="312" dy="16" font-size="11.5" font-weight="400">Customer</tspan></text>
  <text x="312" y="144" font-size="11.5" text-anchor="middle" fill="#5A6472">同質化競争</text>
  <text x="312" y="228" font-size="11.5" text-anchor="middle" fill="#5A6472">激戦領域</text>
  <rect x="216" y="232" width="120" height="28" rx="8" fill="#fff" fill-opacity="0.85"/>
  <text x="276" y="251" font-size="12" font-weight="700" text-anchor="middle" fill="#1D7A4E">勝てる領域</text>
</svg>
```

When exceeding the limit: a Venn diagram with 4 or more sets becomes unreadable. Split the
viewpoints in two and make two 2–3 set Venn diagrams, or switch to a comparison table.

## ⑩ Cycle Diagram (PDCA type)

Structure conveyed: A cyclical process (e.g., PDCA). Nodes are placed in a ring, with curved arrows
showing the direction of rotation. Only the starting node is emphasized in dark navy.
Constraints: 4–6 nodes / node label up to 8 full-width characters, 2 lines max / center label up to
6 full-width characters / viewBox 624×416.

```svg
<svg viewBox="0 0 624 416" role="img" aria-label="Plan・Do・Check・Actionが循環するPDCAサイクル図">
  <defs><marker id="p10" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0,0L10,5L0,10z" fill="#113160"/></marker></defs>
  <path d="M393,70 A192,152 0 0 1 486,144" fill="none" stroke="#113160" stroke-width="2" marker-end="url(#p10)"/>
  <path d="M486,272 A192,152 0 0 1 393,346" fill="none" stroke="#113160" stroke-width="2" marker-end="url(#p10)"/>
  <path d="M231,346 A192,152 0 0 1 138,272" fill="none" stroke="#113160" stroke-width="2" marker-end="url(#p10)"/>
  <path d="M138,144 A192,152 0 0 1 231,70" fill="none" stroke="#113160" stroke-width="2" marker-end="url(#p10)"/>
  <rect x="248" y="32" width="128" height="48" rx="8" fill="#113160"/>
  <text x="312" y="52" font-size="13" font-weight="700" text-anchor="middle" fill="#fff"><tspan x="312">Plan</tspan><tspan x="312" dy="17" font-size="11.5" font-weight="400">計画</tspan></text>
  <rect x="440" y="184" width="128" height="48" rx="8" fill="#E8EDF5" stroke="#C9D6E8"/>
  <text x="504" y="204" font-size="13" font-weight="700" text-anchor="middle" fill="#113160"><tspan x="504">Do</tspan><tspan x="504" dy="17" font-size="11.5" font-weight="400">実行</tspan></text>
  <rect x="248" y="336" width="128" height="48" rx="8" fill="#E8EDF5" stroke="#C9D6E8"/>
  <text x="312" y="356" font-size="13" font-weight="700" text-anchor="middle" fill="#113160"><tspan x="312">Check</tspan><tspan x="312" dy="17" font-size="11.5" font-weight="400">評価</tspan></text>
  <rect x="56" y="184" width="128" height="48" rx="8" fill="#E8EDF5" stroke="#C9D6E8"/>
  <text x="120" y="204" font-size="13" font-weight="700" text-anchor="middle" fill="#113160"><tspan x="120">Action</tspan><tspan x="120" dy="17" font-size="11.5" font-weight="400">改善</tspan></text>
  <rect x="240" y="184" width="144" height="48" rx="24" fill="#F0F2F5"/>
  <text x="312" y="213" font-size="13" text-anchor="middle" fill="#5A6472">改善サイクル</text>
</svg>
```

When exceeding the limit: a cycle with 7 or more nodes can't be followed. Bundle consecutive steps
down to 6 or fewer, or extract the non-cyclical part into a Flowchart ④.

## ⑪ Gantt Chart (simple schedule)

Structure conveyed: A schedule of tasks against time. A cleaned-up, presentation-ready schedule (use
mermaid's `gantt` when automatic dependency calculation and rendering are needed).
Constraints: up to 6 rows / up to 6 time-period columns / task name up to 8 full-width characters,
2 lines max / viewBox 624×264.

```svg
<svg viewBox="0 0 624 264" role="img" aria-label="要件定義からリリースまでの4か月の工程表">
  <g stroke="#DDE1E6"><line x1="152" y1="24" x2="152" y2="248"/><line x1="264" y1="24" x2="264" y2="248"/><line x1="376" y1="24" x2="376" y2="248"/><line x1="488" y1="24" x2="488" y2="248"/><line x1="600" y1="24" x2="600" y2="248"/></g>
  <g font-size="12" fill="#5A6472" text-anchor="middle"><text x="208" y="40">4月</text><text x="320" y="40">5月</text><text x="432" y="40">6月</text><text x="544" y="40">7月</text></g>
  <g font-size="13" fill="#333333">
    <text x="16" y="72">要件定義</text>
    <text x="16" y="112">基本設計</text>
    <text x="16" y="152">開発・実装</text>
    <text x="16" y="185" font-size="11.5"><tspan x="16">結合テスト・</tspan><tspan x="16" dy="14">受入テスト</tspan></text>
    <text x="16" y="232">リリース</text>
  </g>
  <rect x="152" y="56" width="112" height="24" rx="5" fill="#113160"/>
  <rect x="208" y="96" width="168" height="24" rx="5" fill="#113160"/>
  <rect x="320" y="136" width="224" height="24" rx="5" fill="#113160"/>
  <rect x="488" y="176" width="112" height="24" rx="5" fill="#113160"/>
  <polygon points="572,218 582,228 572,238 562,228" fill="#FF9900"/>
  <text x="572" y="252" font-size="11" text-anchor="middle" fill="#8F4F00">正式リリース</text>
</svg>
```

When exceeding the limit: if there are more than 7 rows, bundle them by phase. Switch to mermaid's
`gantt` for long, multi-month, multi-stage dependencies.

## ⑫ Funnel Diagram

Structure conveyed: A process where numbers narrow down through stages (e.g., a marketing funnel,
hiring pipeline). Stage width = the number remaining. Attach the actual count and pass-through rate
on the right.
Constraints: up to 5 stages / in-stage label up to 10 full-width characters, 2 lines max /
right-side numeric label up to 8 full-width characters / viewBox 624×336.

```svg
<svg viewBox="0 0 624 336" role="img" aria-label="サイト訪問から受注まで4段階で絞り込まれるファネル図">
  <polygon points="32,24 496,24 454,88 74,88" fill="#113160"/>
  <text x="264" y="53" font-size="13" font-weight="700" text-anchor="middle" fill="#fff"><tspan x="264">サイト訪問</tspan><tspan x="264" dy="17" font-size="11.5" font-weight="400">（月間UU）</tspan></text>
  <polygon points="80,96 448,96 406,160 122,160" fill="#40699F"/>
  <text x="264" y="133" font-size="13" font-weight="700" text-anchor="middle" fill="#fff">資料請求</text>
  <polygon points="128,168 400,168 358,232 170,232" fill="#7595BE"/>
  <text x="264" y="205" font-size="13" font-weight="700" text-anchor="middle" fill="#14273E">商談化</text>
  <polygon points="176,240 352,240 310,304 218,304" fill="#A8BCD9"/>
  <text x="264" y="277" font-size="13" font-weight="700" text-anchor="middle" fill="#14273E">受注</text>
  <g font-size="12" fill="#5A6472"><text x="520" y="60">10,000</text><text x="520" y="132">1,200</text><text x="520" y="204">300</text><text x="520" y="276">60</text></g>
  <g font-size="11" fill="#8F4F00"><text x="520" y="96">↓ 12%</text><text x="520" y="168">↓ 25%</text><text x="520" y="240">↓ 20%</text></g>
</svg>
```

When exceeding the limit: if there are more than 6 stages, bundle the middle stages down to 5 or
fewer (don't shrink a stage's height to cram it in — the text will overflow the stage).

## ⑬ Roadmap (timeline × lanes)

Structure conveyed: An overall plan across a timeline (phases) × initiative categories. Milestones
are placed as ◆ markers (use Gantt ⑪ for ground-level weekly schedules).
Constraints: up to 4 lanes / up to 4 phases / bar label up to 9 full-width characters, 2 lines max /
lane name up to 5 full-width characters / viewBox 624×320.

```svg
<svg viewBox="0 0 624 320" role="img" aria-label="3フェーズ×3レーンのロードマップ図">
  <g font-size="12" font-weight="700" text-anchor="middle" fill="#fff">
    <rect x="128" y="24" width="160" height="32" rx="6" fill="#113160"/><text x="208" y="44">Phase 1（基盤）</text>
    <rect x="288" y="24" width="160" height="32" rx="6" fill="#113160"/><text x="368" y="44">Phase 2（拡張）</text>
    <rect x="448" y="24" width="160" height="32" rx="6" fill="#113160"/><text x="528" y="44">Phase 3（定着）</text>
  </g>
  <rect x="16" y="64" width="592" height="80" fill="#F0F2F5"/>
  <rect x="16" y="144" width="592" height="80" fill="#fff"/>
  <rect x="16" y="224" width="592" height="80" fill="#F0F2F5"/>
  <g font-size="12" font-weight="700" fill="#5A6472"><text x="24" y="108">プロダクト</text><text x="24" y="188">データ</text><text x="24" y="268">運用</text></g>
  <rect x="144" y="88" width="152" height="32" rx="6" fill="#113160"/>
  <text x="220" y="108" font-size="12" text-anchor="middle" fill="#fff">認証基盤の刷新</text>
  <rect x="312" y="88" width="152" height="32" rx="6" fill="#E8EDF5" stroke="#C9D6E8"/>
  <text x="388" y="108" font-size="12" text-anchor="middle" fill="#113160">新ダッシュボード</text>
  <rect x="224" y="168" width="152" height="32" rx="6" fill="#E8EDF5" stroke="#C9D6E8"/>
  <text x="300" y="188" font-size="12" text-anchor="middle" fill="#113160">データ基盤整備</text>
  <rect x="392" y="168" width="152" height="32" rx="6" fill="#E8EDF5" stroke="#C9D6E8"/>
  <text x="468" y="180" font-size="11.5" text-anchor="middle" fill="#113160"><tspan x="468">ダッシュボード</tspan><tspan x="468" dy="15">全社展開</tspan></text>
  <rect x="464" y="248" width="136" height="32" rx="6" fill="#E8EDF5" stroke="#C9D6E8"/>
  <text x="532" y="268" font-size="12" text-anchor="middle" fill="#113160">監視の自動化</text>
  <polygon points="440,254 450,264 440,274 430,264" fill="#FF9900"/>
  <text x="440" y="296" font-size="11" text-anchor="middle" fill="#8F4F00">本番移行</text>
</svg>
```

When exceeding the limit: if there are more than 5 lanes, consolidate categories. Switch to Gantt ⑪
once the exact start/end timing of bars becomes the point at issue.

## ⑭ Swimlane Diagram

Structure conveyed: A business process by department or owner (who, when). Vertical position =
owner, horizontal position = time. Arrows cross lanes as right-angle bent lines.
Constraints: up to 4 lanes / up to 6 boxes / box label up to 7 full-width characters, 2 lines max /
lane name up to 4 full-width characters / viewBox 624×312.

```svg
<svg viewBox="0 0 624 312" role="img" aria-label="営業・法務・経理をまたぐ契約プロセスのスイムレーン図">
  <defs><marker id="p14" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0,0L10,5L0,10z" fill="#113160"/></marker></defs>
  <rect x="96" y="24" width="512" height="88" fill="#fff" stroke="#DDE1E6"/>
  <rect x="96" y="112" width="512" height="88" fill="#F0F2F5" stroke="#DDE1E6"/>
  <rect x="96" y="200" width="512" height="88" fill="#fff" stroke="#DDE1E6"/>
  <rect x="16" y="24" width="80" height="88" fill="#E8EDF5" stroke="#DDE1E6"/>
  <rect x="16" y="112" width="80" height="88" fill="#E8EDF5" stroke="#DDE1E6"/>
  <rect x="16" y="200" width="80" height="88" fill="#E8EDF5" stroke="#DDE1E6"/>
  <g font-size="12" font-weight="700" text-anchor="middle" fill="#113160"><text x="56" y="72">営業</text><text x="56" y="160">法務</text><text x="56" y="248">経理</text></g>
  <rect x="112" y="44" width="112" height="48" rx="8" fill="#fff" stroke="#C9D6E8"/>
  <text x="168" y="73" font-size="12" text-anchor="middle" fill="#113160">見積・契約作成</text>
  <rect x="240" y="132" width="112" height="48" rx="8" fill="#fff" stroke="#C9D6E8"/>
  <text x="296" y="153" font-size="12" text-anchor="middle" fill="#113160"><tspan x="296">契約条件の</tspan><tspan x="296" dy="16">リーガル審査</tspan></text>
  <rect x="368" y="44" width="112" height="48" rx="8" fill="#fff" stroke="#C9D6E8"/>
  <text x="424" y="73" font-size="12" text-anchor="middle" fill="#113160">顧客と契約締結</text>
  <rect x="496" y="220" width="104" height="48" rx="8" fill="#fff" stroke="#C9D6E8"/>
  <text x="548" y="249" font-size="12" text-anchor="middle" fill="#113160">請求書の発行</text>
  <path d="M224,68 H232 V156 H236" fill="none" stroke="#113160" stroke-width="2" marker-end="url(#p14)"/>
  <path d="M352,156 H424 V96" fill="none" stroke="#113160" stroke-width="2" marker-end="url(#p14)"/>
  <path d="M480,68 H488 V244 H492" fill="none" stroke="#113160" stroke-width="2" marker-end="url(#p14)"/>
  <text x="608" y="308" font-size="11" text-anchor="end" fill="#5A6472">時間 →</text>
</svg>
```

When exceeding the limit: if there are more than 7 boxes, raise the granularity to bundle the work,
or split into two diagrams by phase. Switch to mermaid's `flowchart` + subgraph for strict business
flows with many branches or decisions.
