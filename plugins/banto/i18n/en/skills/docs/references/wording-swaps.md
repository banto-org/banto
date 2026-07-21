# wording-swaps — Canonical Swap List for Stiff Expressions (machine-checked: scripts/style-sweep.py)

Patterns in everyday business writing that read as "stiff, translation-ese, or redundant,"
together with their replacements. Collects patterns that JTF-style style guides, official
textlint rules (ja-no-redundant-expression, etc.), and editorial practice columns all flag in
agreement. Full rationale: `{base}/docs/research/2026-07-20_stiff-japanese-rewrite-table.md`.

Workflow: after writing, run `scripts/style-sweep.py` → judge each flagged line one by one →
either rewrite it, or, if you're deliberately keeping it, register it in the exclusion list
(this becomes a record of the judgment call) → re-run until detections are zero.

## 1. Swap table (most frequent. ✗ problem → ✓ fix)

| ✗ Stiff / redundant | ✓ Swap | Note |
|---|---|---|
| 〜することができる ("is able to do 〜") | 〜できる ("can do 〜") | The most frequent redundancy. The potential form alone is enough |
| 〜することが可能である ("it is possible to do 〜") | 〜できる ("can do 〜") | Same. Turning it into a noun predicate makes it even stiffer |
| 〜されうる／〜し得る ("can be 〜ed / could 〜") | 〜される可能性がある／〜されることがある ("there is a possibility of being 〜ed / it can be 〜ed") | In everyday documents, "され得る" reads as stiff |
| 〜たりうる ("could become 〜") | 〜になりうる／〜となる可能性がある ("can become 〜 / there's a possibility of becoming 〜") | Open up the literary sentence ending |
| （サ変名詞）を行う ("carry out (verbal noun)") | （サ変名詞）する ("do (verbal noun)", e.g. 調査を行う→調査する: "carry out an investigation" → "investigate") | "処理を行う" ("carry out processing") and "katakana word + を行う" are acceptable |
| （サ変名詞）を実行する ("execute (verbal noun)") | （サ変名詞）する ("do (verbal noun)") | Same as above |
| 〜において ("in/at 〜", formal) | で／では ("in/at 〜", plain) | Use "で" outside formal contexts |
| 〜に関して ("regarding 〜") | 〜について ("about 〜") | "に関して" is the stiffer of the two |
| 〜に基づき ("based on 〜", formal) | 〜をもとに／〜に沿って ("based on 〜 / in line with 〜") | Open it up when a legal-document tone isn't needed |
| しかしながら ("however", formal) | しかし ("but/however") | A redundant reversal marker |
| 一面においては ("looking at one aspect") | 一方で ("on the other hand") | A literary lead-in |
| その結果として ("as a result of that") | その結果 ("as a result") | "として" is unnecessary |
| であると言えます ("it can be said that it is") | である／と言えます (pick one) | Doubling up the assertive function |
| であると考えている ("it is thought that it is") | である／と考えている (pick one) | Same |
| であろう ("it will probably be", literary) | 〜と推測される／だろう ("it is presumed that… / probably") | Open up the literary auxiliary |
| 〜であるところの ("that which is 〜") | (cut it — modify the noun directly) | Not used in modern everyday documents |
| 一番最初／まず最初 ("the very first / first of all") | 最初（に） ("first") | Double expression |
| 〜のではないか ("isn't it the case that 〜") | 〜ではないか ("isn't it 〜") | The "の" adds nothing |
| 完全に／非常に／極めて ("completely / very / extremely") | (delete as a rule) | Emphasis with no backing is an empty word — replace with a number |
| 重要なのは〜である／まとめると ("what matters is 〜 / to summarize") | (skip the preview — just write the content) | An LLM-specific preview/summary tic |
| 〜と言えるだろう ("one could say that 〜") | state it plainly / 〜と考えられる ("it is thought that 〜") | Ungrounded hedging weakens the claim |

"〜に対して" ("toward/against 〜") is a function word marking a target or direction, not a
topic — don't blanket-replace it just because it sounds stiff (that changes the meaning).

## 2. Modality certainty table (choosing among ways to avoid a flat assertion)

The axis isn't "stiff vs. soft" but **certainty** and **positive/negative polarity**. Collapsing
everything to "かもしれない" ("might") changes the meaning.

| Expression | Certainty | Polarity | When to use |
|---|---|---|---|
| Flat assertion（〜だ・〜である） | Established fact | Neutral | Direct statement of fact. State it plainly when the basis is clear |
| 〜と考えられる ("it is thought that 〜") | High (based on data/analysis) | Neutral | Logical inference. More objective than "思われる" |
| 〜とみなされる ("it is deemed 〜") | High (application of a rule/standard) | Neutral to negative | Only for judgments under regulation, contract, or law. Not for personal opinion |
| 〜可能性がある ("there is a possibility of 〜") | Medium (wide range) | **Either (neutral)** | The default for objective prediction. First choice for formal documents |
| 〜見込みだ ("expected to 〜") | Medium to high (grounded, forward-looking prediction) | Leans positive | Outlook for performance or plans |
| 〜おそれがある ("there is a risk of 〜") | Regardless of high/low | **Negative only** | Risk warnings and cautions only |
| 〜場合がある ("there are cases where 〜") | Conditional occurrence | Neutral | Manuals and terms of service (always attach the condition) |
| 〜と思われる ("it seems that 〜") | Low to medium (impression-based) | Neutral | Restrained personal opinion. In reports, prefer "考えられる" |
| 〜かもしれない ("might 〜") | Low (subjective) | Neutral | Conversational register. Avoid in reports and proposals |

## 3. Judgment tips

- If the flagged expression is in a **formal notice, contract, or legal-register context**, it's
  fine to keep it (e.g. "〜により"). Register it in the exclusion list with the reason
- When a rewrite would **change the meaning** (certainty, target, or binding force), pick the
  expression in table 2 with the same certainty and the same polarity
- When in doubt, read it aloud. A word that sounds unnatural spoken is stiff in writing too
