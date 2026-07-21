# writing-core — Core Writing Patterns Common to All Formats (Three Layers: Cognition → Persuasion → Scene)

Learn each rule as a ✗ problem → ✓ fix pair. The rationale for each is collected in the "Source
mapping" section at the end.

When in doubt, err on the side of reducing the reader's memory burden (working memory holds about
4±1 chunks. A document that's hard to read loses the reader's trust before its content is even
judged — this is processing fluency).

## Layer 1: Cognition — Read without stopping

### Sentences
1. **One claim per sentence, aim for 50–60 characters**: a sentence should carry one claim. Don't
   chain claims with "〜ので" ("because") or "〜が" ("but/and").
   - ✗「本機能は要望が多かったので実装したが、設定が必要だが既定では無効である」(chains three
     claims with "ので"/"が": "we implemented this feature because there were many requests, but
     it needs configuration and is off by default")
   - ✓「本機能は要望を受けて実装した。既定では無効になっている。使うには設定が必要だ」(split
     into three sentences: "We built this feature in response to requests." "It's off by
     default." "You need to configure it to use it.")
2. **At most 3 commas (読点) per sentence.** If a fourth is needed, split the sentence.
3. **Known → new**: pick up the new information from the previous sentence at the start of the
   next one.
   - ✗「7月に新プランを公開します。料金の改定も行われます」("We'll release the new plan in
     July. Pricing will also be revised." — the second sentence doesn't pick up "new plan")
   - ✓「7月に新プランを公開します。新プランでは、料金が下がります」("We'll release the new
     plan in July. Under the new plan, pricing goes down." — "新プラン" bridges the two sentences)
4. **Basic word order**: when, where, who, what, how. Keep the subject and predicate close
   together.
5. **No double negatives**: ✗「対応できないわけではない」("It's not that we can't support it")
   → ✓「条件付きで対応できる」("We can support it, conditionally")
6. **No chains of the same conjunctive particle.** The reversal particle "が" ("but") at most once
   per sentence.
7. **Vary the rhythm deliberately**: vary sentence length and the number of sentences per
   paragraph on purpose. A uniform rhythm is the single biggest tell of AI-generated text.

### Words
8. **Concrete words + numbers left unrounded**: choose words where the action and the figures are
   visible. Numbers with fractional digits read as more credible.
   - ✗「多くのお客様にご利用いただいています」("Used by many of our customers") →
     ✓「同業種のお客様の78.3%が契約を更新しています」("78.3% of customers in the same industry
     renew their contracts")
   - ✗「業務を最適化する」("Optimize operations") → ✓「締め作業を月6時間短縮する」("Cut
     month-end closing work by 6 hours a month")
9. **Open up stiff expressions**: e.g. "されうる" ("can be done") → "可能性がある" ("there is a
   possibility that"). The canonical swap table is `wording-swaps.md`. Run
   `scripts/style-sweep.py` after writing to catch these mechanically.
10. **Choose modality by degree of certainty**: 可能性がある (possibility) = neutral, works
    either way / おそれがある (risk of) = negative-only / 見込み (expected to) = leans positive
    (see the certainty-mapping table in `wording-swaps.md` section 2).
11. **Four categories of loanwords**: established loanwords stay in katakana / loanwords with an
    easy native equivalent get opened up (アジェンダ→議題, "agenda" → the native term for "agenda
    item") / loanwords hard to replace get a gloss / loanwords still settling into the language
    get handled case by case.
12. **Avoid single-kanji + する ("suru") verbs** (模する→似せる, "emulate" → "resemble"). No
    more than 6 consecutive kanji characters.
13. **Define on first use**: abbreviations and jargon get "full name (abbreviation)" on first
    appearance. Use a demonstrative/referential word only when its referent is immediately before
    it.

### Structure
14. **Always follow an abstraction with something concrete**: after stating a definition or claim,
    put an example, a number, or a proper noun in the very next sentence.
15. **Anticipate the reader's next question**: after finishing each paragraph, ask yourself "what
    will the reader wonder here?" and answer it at the top of the next paragraph. This is the
    single most common pattern across well-written prose.
16. **Reason first, instruction second**: order as "〜だから、〜してください" ("because X,
    please do Y"). Get the reader to agree before asking them to act.
17. **Any structural explanation longer than 3 lines becomes a diagram or table** (comparisons,
    correspondences, flows, hierarchies, rankings). Once it's a diagram, don't repeat it in prose
    (redundancy effect).
18. **Headings are message sentences**: ✗「売上推移」("Sales trend") → ✓「売上は3期連続で
    12%成長」("Sales have grown 12% for three consecutive periods"). The body text supplies the
    evidence for that heading (assertion-evidence method — applies to headings in every format,
    not just slides).
19. **One topic per paragraph, 3–5 sentences**: put the paragraph's conclusion in its first
    sentence (topic sentence). The test: skim only the first sentence of every paragraph — the
    argument should still hold together.

## Layer 2: Persuasion — Getting the reader to act

The axis is **the reader's level of involvement** (Elaboration Likelihood Model, ELM). For highly
involved readers (decision-makers, experts), stack up supporting arguments; for low-involvement
readers (recipients of a blanket announcement), foreground the conclusion and credibility signals.

20. **State the conclusion explicitly by default**: ✗「各部門は対応をご検討ください」("Please
    have each department consider a response") → ✓「各部門は8月末までにA対応を実施してください」
    ("Each department must implement response A by the end of August"). Exception: for
    highly-involved expert readers, laying out the evidence and leaving room for their own
    judgment can work better.
21. **Direction of framing**: use a loss frame to drive action, a gain frame to report results.
    - Call to action: ✗「切り替えると月5万円削減できます」("Switching saves you ¥50,000 a
      month") → ✓「切り替えないと年間60万円を失い続けます」("Not switching keeps costing you
      ¥600,000 a year")
    - Results reporting: ✗「未達率は20%です」("The miss rate is 20%") → ✓「達成率は80%です」
      ("The achievement rate is 80%")
22. **Always pair a counterargument with a rebuttal**: stating a concern without rebutting it is
    **less** persuasive than not mentioning it at all.
    - ✗「コストは他社より15%高いです。しかし品質には自信があります」("Cost is 15% higher than
      competitors. But we're confident in the quality.")
    - ✓「コストは他社より15%高い。ただし保守費込みの5年総額では約200万円安くなる」("Cost is
      15% higher than competitors. However, including maintenance, the 5-year total is about
      ¥2,000,000 cheaper.")
23. **Social proof as a ratio within a bounded population**: ✗「多数の導入実績」("Adopted by
    many") → ✓「同業50社のうち39社が導入」("39 of 50 companies in the same industry have
    adopted it")
24. **Vivid scene-setting is fine to use, but don't over-rely on it** (the evidenced effect size
    is small to medium): ✓「以前は月末に3人で深夜まで。今は1人で定時内に終わる」("It used to
    take 3 people working until midnight at month-end. Now one person finishes within regular
    hours."). Only dramatize scenes backed by fact.
25. **Translate into benefits**: make the subject "how the reader's work changes," not the
    feature itself.
    - ✗「検索機能を改善しました」("We improved the search feature") →
      ✓「検索条件に部署名を追加しました。部署単位の絞り込みが1手でできます」("We added
      department name as a search filter. You can now filter by department in one step.")

## Layer 3: Scene — Conventions by document type

| Scene | Structure | Style / prohibitions |
|---|---|---|
| Report | Conclusion-first (5W1H summary → detail → findings) | Separate fact from finding. ✗「順調です」("Going smoothly") → ✓「進捗率80%、2日前倒し」("80% progress, 2 days ahead of schedule") |
| Proposal | **Conclusion-last** (share the problem → solution → quantified impact → cost → conclusion) | Assertive tone. No「〜と思われます」("it is thought that…"). State impact in numbers |
| B2B proposal (client-facing) | Cover = one message (the outcome the client gets, not the product name, in one sentence) → problem → impact → evidence → cost and schedule → implementation steps → risks and mitigations | Show impact as before → after pairs of actual numbers, with the source cited in the evidence chapter. Don't end cost with "quote available on request" — give an approximate range. No self-promotion, no exhaustive feature lists, no impact claims without numbers |
| Request | Conclusion-first (summary → reason → deadline) | Cushioning language + polite-inquiry form. ✗「お早めに」("As soon as possible") → ✓「7/25（金）17時までに」("By 17:00 on Friday, July 25") |
| Apology | Apology → facts (5W1H) → cause → remedy → repeat apology | Don't lead with excuses. Don't blur where responsibility lies. Don't make firm promises you can't keep (✗「必ず本日中に復旧」("We will definitely restore it today") → ✓「18時までに暫定対応、恒久対応は〇日に報告」("Temporary fix by 18:00; permanent fix reported on the Xth")) |
| Release notes | Facts → background → what it means for the user | No vague verbs (✗ 改善しました("improved") → ✓ 追加/変更/修正しました("added/changed/fixed")) |

- Reports and requests = conclusion-first; proposals = conclusion-last. This asymmetry maps to
  ELM involvement (a proposal raises the reader's involvement by sharing the problem first, then
  delivers the conclusion). B2B client-facing proposals are the one exception on the cover — show
  the one-sentence outcome the client gets first, then build up the body from the problem.
- Keep style consistent within one document (never mix です・ます and である endings).
  External-facing documents stay at polite level; avoid double honorifics.

## Structural templates (overall skeleton)

| Template | Structure | When to use |
|---|---|---|
| BLUF | One-line conclusion up front | Line 1 of every document |
| PREP | Conclusion → Reason → Example → Conclusion | Each section of persuasive/proposal writing |
| SDS | Summary → Detail → Summary | Objective reporting |
| Pyramid | Conclusion at the apex, evidence decomposed with no overlap and no gaps (MECE) | Overall skeleton of reports and proposals |

Layer these by granularity: the whole document = pyramid, the opening = BLUF, each section = PREP
or SDS. Only when the scene is a proposal does the overall conclusion's position follow the
Layer 3 convention (conclusion-last).

## Removing the "AI voice" (final pass before delivery)

- Cut preview/summary phrases: 「重要なのは〜」("What matters is…"), 「まとめると」("To sum up"),
  「本章では〜を扱う」("This chapter covers…")
- Cut empty modifiers: 「不可欠」("essential"), 「核心的」("core"), 「鍵となる」("key"),
  「非常に」("very"), 「極めて」("extremely") → replace with actual numbers/facts
- Cut repeated connectives: overuse of 「さらに」("furthermore"), 「また」("also"), 「加えて」
  ("in addition")
- Cut ungrounded hedging: 「〜と言えるだろう」("one could say that…") → either assert it plainly
  or use a calibrated certainty expression
- Cut mechanical bold-bullet emphasis (「**重要**:」("**Important**:") or emoji prefixes)

## The four conditions for zero friction

| Friction | Countermeasure |
|---|---|
| A term the reader has to look up | Gloss on first use + glossary (the method lives in each format's "term glossing" section) |
| An external claim with no backing | Cite the source right after the claim |
| A structural explanation pushed through in prose | Anything over 3 lines becomes a diagram or table |
| A document whose reading order is unclear | A legend at the top |

## Source mapping (rule number → basis. Details in the store's three research docs: 2026-07-20_persuasion-and-scene-writing-ja / 2026-07-20_stiff-japanese-rewrite-table / 2026-07-11_ja-exemplary-techwriting-realexamples)

- 1, 3–6, 11, 12: Agency for Cultural Affairs, "公用文作成の考え方" (2022) / SmartHR Design
  System, "伝わる文章"
- 2, 6, 12: textlint preset-ja-technical-writing
- 8: Schindler & Yalch 2006 (credibility of unrounded numbers) / 14–16: analysis of exemplary
  Japanese prose (Yuki, Tokumaru, IPA, and others)
- Persuasion-layer axis: Petty & Cacioppo 1986 (ELM) / 20: O'Keefe 1997 / 21: Tversky & Kahneman
  1981 / 22: Allen 1991 / 23: Goldstein, Cialdini & Griskevicius 2008 / 24: Blondé & Girandola
  2016 (all meta-analyses or primary sources)
- 25, scene layer: SmartHR release-notes guide / Adobe, Money Forward, Cybozu practitioner guides
- Removing the "AI voice": Keiichiro Shikano, "japanese-tech-writing" / textlint ai-writing preset
