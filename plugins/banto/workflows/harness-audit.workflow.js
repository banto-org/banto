export const meta = {
  name: 'harness-audit',
  description: 'banto ハーネス全体を 5 軸で並列監査し、各指摘を検証して合成する',
  whenToUse: 'ハーネス全体のシステム監査を deterministic な多エージェントで thorough に回したいとき（/harness-audit の thorough モード）。args.mode="network" で system 5軸 + 全 skill 品質を3層 fan-out（静的全網羅→候補駆動判定）で一気に網羅。',
  phases: [
    { title: '軸監査', detail: '5 軸を並列 audit（各軸が構造化 findings を返す）' },
    { title: '検証', detail: '各 finding を独立 agent が反証ベースで検証' },
    { title: '静的全網羅', detail: 'network mode: 全 skill の plugin-audit 静的軸を 1 回で網羅し候補抽出（haiku）' },
    { title: 'per-skill 判定', detail: 'network mode: 静的が flag した候補を per-skill で確定（sonnet）' },
    { title: '合成', detail: '確定 finding を北極星基準で優先度付けして報告' },
  ],
}

// args: { cwd?: string } — 監査対象 repo（省略時は agent が自己解決）
const CWD = (args && args.cwd) ? args.cwd : '.'

const FINDINGS = {
  type: 'object',
  additionalProperties: false,
  required: ['axis', 'findings'],
  properties: {
    axis: { type: 'string' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['title', 'severity', 'evidence'],
        properties: {
          title: { type: 'string' },
          severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low'] },
          evidence: { type: 'string', description: 'file:line / コマンド出力など具体的根拠' },
        },
      },
    },
  },
}

const VERDICT = {
  type: 'object',
  additionalProperties: false,
  required: ['title', 'confirmed', 'reason'],
  properties: {
    title: { type: 'string' },
    confirmed: { type: 'boolean', description: '反証を試みた上でなお実在する指摘か' },
    reason: { type: 'string' },
  },
}

// network mode: Tier1 静的全網羅が返す「判定 agent に回すべき候補」
const CANDIDATES = {
  type: 'object',
  additionalProperties: false,
  required: ['candidates'],
  properties: {
    candidates: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['skill', 'axis', 'note'],
        properties: {
          skill: { type: 'string' },
          axis: { type: 'string', description: 'plugin-audit 軸（4/5/6/8/12 等）' },
          note: { type: 'string', description: '静的が flag した根拠（file:line / over-grant 等）' },
        },
      },
    },
  },
}

const AXES = [
  {
    key: '思想整合',
    prompt: `harness-audit 軸1（思想整合）。CWD=${CWD}。CONCEPT.md の北極星・反NG宣言に反する仕組み（人間の承認ゲート儀式 / always-on rule の肥大 / modal な質問 / 死蔵の温存 / 宣言と実体の乖離）を探す。CLAUDE.md / CONCEPT.md / skills/*/SKILL.md / hooks を read-only で検査。各指摘に file:line の根拠を付ける。`,
  },
  {
    key: '呼び出し実態',
    prompt: `harness-audit 軸2（呼び出し実態・死蔵検出）。CWD=${CWD}。\`sh "$CLAUDE_PLUGIN_ROOT/scripts/telemetry-summary.sh" --days 30 ${CWD}\` を実行し invocation + artifact を集計。window 内 invocation 0 かつ artifact 0 が継続する skill を死蔵候補に。telemetry 蓄積 2 週未満なら「データ不足」と明記し断定しない。`,
  },
  {
    key: '最新化',
    prompt: `harness-audit 軸3（最新化・乖離）。CWD=${CWD}。\`sh "$CLAUDE_PLUGIN_ROOT/scripts/harness-drift-check.sh" ${CWD}\` を実行し、編集 repo↔live cache の version/内容乖離を検出。CHANGELOG / plugin.json / CLAUDE.md のカウント宣言が実体と一致するかも grep で照合。`,
  },
  {
    key: 'インストール方針整合',
    prompt: `harness-audit 軸4（宣言整合）。CWD=${CWD}。委譲宣言がネイティブ /code-review・/security-review を指しているか（banto は公式プラグインを自動 install しない＝委譲≠install。install 前提の記述が残っていれば乖離）を grep で確認。さらに plugin.json / CLAUDE.md / README / kit のカウント宣言・skill 一覧に削除済み skill（init-harness 等）参照が残っていないか、PLUGIN_EXCLUDE 後の公開 skill 数と宣言が一致するかを照合する。`,
  },
  {
    key: 'Claude機能整合',
    prompt: `harness-audit 軸5（Claude 機能整合）。CWD=${CWD}。skills/*/SKILL.md の allowed-tools / hooks.json が現行 Claude Code 仕様と矛盾しないか。AskUserQuestion の positive 指示が残っていないか（askuser-deny で block されるのに使えと指示していないか）。未使用 hook イベント・壊れた配線が無いか。`,
  },
]

// model 委譲（decision 2026-06-12-113500）: 機械的軸=haiku / 判定軸=sonnet / 合成は main 継承（最高価値判断）。
// 未指定だと親 fable5 継承でコスト爆発するため、worker は必ず明示する。
const AXIS_MODEL = { '思想整合': 'sonnet', '呼び出し実態': 'haiku', '最新化': 'haiku', 'インストール方針整合': 'haiku', 'Claude機能整合': 'sonnet' }

phase('軸監査')
// 5 軸を pipeline で流す。各軸: audit → findings を検証 → 確定のみ残す。
const perAxis = await pipeline(
  AXES,
  (a) => agent(a.prompt, { model: AXIS_MODEL[a.key] || 'sonnet', label: `audit:${a.key}`, phase: '軸監査', schema: FINDINGS }),
  (res, a) => {
    if (!res || !res.findings || res.findings.length === 0) return { axis: a.key, confirmed: [] }
    return parallel(
      res.findings.map((f) => () =>
        agent(
          `次の harness-audit 指摘を反証ベースで検証せよ（軸=${a.key}）。実在を疑い、根拠 "${f.evidence}" を自分で確認せよ。誤検知や既知の許容なら confirmed=false。\n指摘: ${f.title}`,
          { model: 'sonnet', label: `verify:${a.key}`, phase: '検証', schema: VERDICT }
        ).then((v) => ({ ...f, axis: a.key, verdict: v }))
      )
    ).then((vs) => ({
      axis: a.key,
      confirmed: vs.filter(Boolean).filter((x) => x.verdict && x.verdict.confirmed),
    }))
  }
)

// network mode（opt-in: args.mode==='network'）— system 5軸に加え per-skill 品質を網羅 fan-out。
// 3層: Tier0 system(上の5軸) / Tier1 静的全網羅(haiku・スクリプト1回で全 skill) / Tier2 候補駆動判定(sonnet)。
// 静的が flag した skill×軸だけを判定 agent に回す（全網羅でなく候補駆動でコスト収束）。
let skillConfirmed = []
if (args && args.mode === 'network') {
  phase('静的全網羅')
  const stat = await agent(
    `harness-audit network — Tier1 静的全網羅。CWD=${CWD}。次の plugin-audit 静的スクリプトを ${CWD}/plugins/banto に対し実行し結果を読め:\n` +
      `\`sh "$CLAUDE_PLUGIN_ROOT/scripts/plugin-audit-collect.sh" ${CWD}/plugins/banto | sh "$CLAUDE_PLUGIN_ROOT/scripts/plugin-audit-report.sh"\`\n` +
      `\`sh "$CLAUDE_PLUGIN_ROOT/scripts/plugin-audit-usage.sh" ${CWD}/plugins/banto\`\n` +
      `\`sh "$CLAUDE_PLUGIN_ROOT/scripts/plugin-audit-permissions.sh" ${CWD}/plugins/banto\`\n` +
      `判定 agent に回すべき候補だけを {skill, axis, note} で列挙せよ（静的が flag した Axis 4/5/6/8/12 等のみ。クリーンな skill は出さない）。`,
    { model: 'haiku', label: 'static:all-skills', phase: '静的全網羅', schema: CANDIDATES }
  )
  const candidates = (stat && stat.candidates) || []
  phase('per-skill 判定')
  const judged = await parallel(
    candidates.map((c) => () =>
      agent(
        `plugin-audit 判定（Reviewer = Fresh Agent）。skill=${c.skill} 軸=Axis ${c.axis}。静的候補の根拠="${c.note}"。\n` +
          `この skill の SKILL.md を read-only で確認し、指摘が確定か誤検知かを判断せよ。references/scoring.md の該当軸基準に従う。`,
        { model: 'sonnet', label: `judge:${c.skill}:${c.axis}`, phase: 'per-skill 判定', schema: VERDICT }
      ).then((v) => ({ skill: c.skill, axis: c.axis, note: c.note, severity: 'medium', verdict: v }))
    )
  )
  skillConfirmed = judged.filter(Boolean).filter((x) => x.verdict && x.verdict.confirmed)
}

phase('合成')
const confirmed = perAxis.filter(Boolean).flatMap((r) => r.confirmed || [])
const bySeverity = (s) => confirmed.filter((f) => f.severity === s)
const summaryInput = JSON.stringify(
  {
    total: confirmed.length,
    critical: bySeverity('critical'),
    high: bySeverity('high'),
    all: confirmed,
    perSkill: skillConfirmed,
  },
  null,
  2
)

const report = await agent(
  `harness-audit の確定指摘を北極星（自走 / lean / deterministic / 乖離ゼロ）基準で優先度付けし、是正アクションを添えて Markdown 報告にまとめよ。critical→high→medium→low の順。各指摘に軸・根拠・推奨アクションを 1 行ずつ。最後に「次の一手」を 3 つ。\n` +
    `network mode の場合 perSkill（per-skill 品質）指摘も統合する。**死蔵判定は telemetry(軸2 invocation=0) かつ usage(軸11 git=0) かつ artifact=0 の3条件 AND のみ確定**（intent-first の自然文発火は invocation 計測に出ない偽陽性に注意・保険価値ルール）。\n\n確定指摘:\n${summaryInput}`,
  { label: 'synthesize', phase: '合成' }
)

return { axes: perAxis, perSkill: skillConfirmed, confirmed_count: confirmed.length + skillConfirmed.length, report }
