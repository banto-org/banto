# plugin-audit verify — 機能検証（「Sensei」に欠けていた eval）

Axis 4 は **routing**（プロンプトに対して正しい skill が発火するか）を測る。`verify` は
**function**（発火後、skill が claim 通りに実際に生成するか）を測る。両者で
routing → execution を end-to-end でカバーする。これは決定 `2026-05-14` が「欠けている」と flag した eval レイヤーである —
plugin-audit は静的 frontmatter（「Sensei」）チェックしか持たず、実実行の eval が無かった。

`verify` は第 15 軸ではなく **サブコマンド** である: 副作用を持ち（skill を end-to-end 実行する）
コストが分単位なので、read-only・秒スケールの軸フレームワークには収まらない。Axis 4 の functional な
下流に位置する。

## Tier — どの skill が検証可能か

| Tier | 意味 | skill | 方法 |
|---|---|---|---|
| **A deterministic** | 出力パス + 必須構造が SKILL.md に宣言され、副作用が ai-context ベースに限定される | memo, spec, save-checkpoint, status, ai-context (decisions) | deterministic な assertion、agent 判定はほぼ無し |
| **B semi** | artifact は生成されるが「内容が正しいか」は判定が要る | search, research | deterministic（構造 + invariant）+ judge 投票 |
| **C judgmental** | 出力が対話 / 提案 / 解釈で、単一の正解が無い | concept, architect, debugger, plugin-dev | verify 免除 → Axis 4 routing + Axis 14 hygiene + dogfooding でカバー |

`verify-cases.yaml` は `skills/<name>/verify-cases.yaml` に置く（schema はヘッダ: `skill` / `tier` /
`fixture` / `assert` / `invariants` を持つ `cases[]`）。verify-cases ファイルを持たない skill は Tier C
（免除）として扱う。`matrix` は verify-cases を欠く Tier A/B の skill を flag する。

## 手順（ケースごと、Tier A/B）

1. **Sandbox** — `base=$(sh "$CLAUDE_PLUGIN_ROOT/scripts/verify-sandbox.sh" start)`。`$TMPDIR` 配下に
   使い捨ての ai-context ベースを作り、`verify-write-guard`（PreToolUse hook）を起動する: `base` 外への Write/Edit は
   **deterministic に block される** ので、検証対象の skill は実 store や repo に触れない。
2. **skill を隔離実行** — `general-purpose` サブエージェント（Reviewer = Fresh Agent）を立て、
   その skill 自身の `allowed-tools` を付与する: *"Load `<skill>`'s SKILL.md. Your ai-context base is `<base>`. Process this
   request: `<fixture.prompt>`. Do exactly what the skill says; write artifacts only under the base."* repo を Bash git で
   変更する Tier B の skill では、使い捨ての `git worktree` を cwd にしてサブエージェントも走らせる。
3. **Assert（deterministic）** — `sh "$CLAUDE_PLUGIN_ROOT/scripts/plugin-audit-verify-assert.sh" --dir "$base"`
   を `case.assert` から変換したフラグで実行する:
   `--glob` / `--headings "A|B"` / `--forbidden "x|y"` / `--no-template-vars "{{"` / `--writes-only-under "docs/"`。
   Exit 0 = 全 pass。
4. **Judge（Tier B のみ）** — 2 つ目のサブエージェントが「この artifact は skill の claim を満たすか」を 0/1 で投票する
   （≥3 票、多数決）。Tier A はこれをスキップする。
5. **Teardown** — `sh "$CLAUDE_PLUGIN_ROOT/scripts/verify-sandbox.sh" stop "$base"`。

ケースごとに報告: pass/fail + 失敗した assertion。skill が `verify` を pass するのは全ケースが pass したときのみ。

## Invariant（assert だけでなく enforce される）
- `writes_only_under` — 事後の `--writes-only-under` assertion に加え、runtime で `verify-write-guard`（PreToolUse）が
  enforce する。
- `no_web_access` — **構造的**: verify サブエージェントには skill 自身の `allowed-tools` のみが付与される。browse してはいけない
  search/webread のような skill は WebSearch/WebFetch の grant をそもそも持たないので、invariant はチェックではなく構成上
  （「構造的に実行不可能にする」原則）成立する。

## コスト / 頻度（opt-in）
`verify` は sandbox + ケースごとのサブエージェント = 分単位で走る。デフォルトの `plugin-audit` には **入らない**。
`plugin-audit verify` で走る。Tier A ケースは安い（ほぼ deterministic）。
Tier B は judge 投票を足す。Telemetry が `verify` の起動回数を数えるので、Axis 11（使用度）が陳腐化を拾う。
