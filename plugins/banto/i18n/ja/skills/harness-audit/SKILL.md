---
name: harness-audit
description: |
  **分析スキル** — banto ハーネス全体を**システム視点**で監査する（vs plugin-audit は個々の skill 品質をスコアリングする）。5 軸: 思想整合、呼び出し実態（死蔵 skill）、最新化（edit-repo vs live-plugin ドリフト）、インストール方針整合、Claude 機能整合（allowed-tools / hooks）。
  トリガー: 「ハーネス監査して」「ハーネス全体をチェック」「死蔵スキルない？」「edit repo と live がズレてないか見て」「システム監査」。/harness-audit でも呼び出し可能。thorough（マルチエージェント Workflow）モードはオプトイン — 明示的な「thorough」/「ultracode」の合図なしには絶対に起動しない。自然言語での発火は軽量な read-only インライン監査のみを実行する。
  使わない場面: 単一 skill の品質スコアリング（plugin-audit）、skill / plugin の生成（plugin-dev）、コードレビュー（code-review）、セキュリティ監査（security-guidance）。
user-invocable: true
argument-hint: "[plugin パス（省略時は plugins/banto）]"
allowed-tools: Read Grep Glob Bash Agent Workflow
compatibility: Claude Code (requires bash, git, jq)
---

# [Audit] Harness Audit — ハーネス全体のシステム監査

> **保存ベース（store-first）**: この skill 内のすべての `.ai-context/...` パスは ai-context ベースを指す — SessionStart hook が「ai-context ベース: &lt;絶対パス&gt;」として注入する絶対パス（不明なときは `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"` で解決）。

**plugin-audit との役割分担**: plugin-audit は「この skill が単体として良い skill か（description / triggers / boundaries / ODD）」を 14 軸でスコアリングする。harness-audit は「**ハーネス全体が原則どおりに機能しているか**」を検査する。たとえ全 skill が満点でも、ある skill が一度も呼び出されない（死蔵）、編集リポジトリと live plugin が乖離している、宣言と実態が乖離している、といった場合システムは壊れている。それを捕まえるのがこの skill の仕事だ。

立脚原則: 呼び出しの主体 = 自走する Claude、例外はチェックポイントのみ、enforcement は hooks に属する。

対象パス: `$ARGUMENTS`（デフォルト `plugins/banto`）。以降 `PLUGIN` と呼ぶ。

ユーザーが日本語で会話している場合は、レポートも応答も日本語で書く。

## 実行モード

- **デフォルト（インライン）**: 下記 5 軸をこのセッション内で Read/Grep/Bash で実行し、主観的な軸（例: 死蔵 skill の判定）のみ Agent に委譲する。軽量で即時。**通常はこれを使う。**
- **thorough（Workflow、オプトインのみ）**: 5 軸を並列エージェントで監査 → 各指摘を adversarial に検証 → 北極星に照らして合成する deterministic なパイプライン。ユーザーが「thorough」「ultracode」等でマルチエージェント実行に**オプトイン**したときのみ:
  ```
  Workflow({ scriptPath: "$CLAUDE_PLUGIN_ROOT/workflows/harness-audit.workflow.js", args: { cwd: "<absolute path of the target repo>" } })
  ```
  オプトインなしには、自分から Workflow を起動しない。インラインで実行する（アンチ「モーダルな質問」/ Workflow はトークンを大量消費する）。
- **network（Workflow、オプトインのみ）**: `args.mode: "network"` 付きの thorough Workflow — システム 5 軸に加え、**skill ごとの品質**を 3 層で fan-out する（Tier1 静的全 skill スクリプト → Tier2 候補駆動の `general-purpose` 判定、model-tiered haiku/sonnet）。1 回の実行でシステム整合性**と**全 skill の品質を網羅する（死蔵判定は 3 条件 AND: telemetry=0 ∧ git=0 ∧ artifact=0）。thorough と同じオプトインゲート、最高コスト — リリース前 / 大規模リファクタに限定する:
  ```
  Workflow({ scriptPath: "$CLAUDE_PLUGIN_ROOT/workflows/harness-audit.workflow.js", args: { cwd: "<absolute path>", mode: "network" } })
  ```

---

## Axis 1: 思想整合（自走原則 / 北極星との一貫性）

「単なる人間の承認ゲートにすぎない儀式」が残っていないか検査する。自走原則のもとでは enforcement は hooks に属する（deterministic）。skill は能力であって承認ゲートではない。

検査:
```sh
# 1a. Is the concept (North Star) @import injected into CLAUDE.md (is the ideology layer wired)?
grep -rl "CONCEPT.md\|北極星\|@import" "$PLUGIN"/.. 2>/dev/null | head

# 1b. Does any skill still list AskUserQuestion in allowed-tools (text-dialogue policy; disabled via askuser-deny)?
grep -rln "AskUserQuestion" "$PLUGIN"/skills/*/SKILL.md "$PLUGIN"/skills/*/odd.yaml 2>/dev/null

# 1c. Human-gate phrasing ("wait for approval" etc., JP + EN patterns) hiding in self-driving skills (needs contextual judgment)
grep -rln "承認を待\|許可を得てから\|ユーザーの指示を待\|wait for approval\|wait for the user\|ask before proceeding\|require user confirmation\|ask for permission" "$PLUGIN"/skills 2>/dev/null
```
判定:
- ❌ 北極星の注入がない → 思想層が浮いている（concept skill の出力が生きていない）
- ❌ AskUserQuestion を保持している skill → 無効化された機能と矛盾する（axis 5 と重複、is_error）
- ⚠ 承認ゲートの言い回し → チェックポイント以外の人間ゲートは原則排除する。文脈で判断し、自走の代替案を提案する

## Axis 2: 呼び出し実態（死蔵 skill 検出）

**呼び出しだけでなく artifact で測る**（呼び出し回数が 0 の skill でも、artifact 経由で機能していることがある）。

検査:
```sh
# 2a+2b+2c. Telemetry aggregation (recorded by telemetry-log.sh)
#   One command prints per-skill invocations + dead candidates + artifacts by prefix.
#   Lists every skill as the denominator; shows skills with 0 invocations in the window as dead candidates.
sh "$CLAUDE_PLUGIN_ROOT/scripts/telemetry-summary.sh" --days 30 "$PWD"

# For machine verdicts, use JSON (the dead_candidates array holds the dead candidates)
sh "$CLAUDE_PLUGIN_ROOT/scripts/telemetry-summary.sh" --json --days 30 "$PWD" \
  | jq '.dead_candidates'
```
判定: ウィンドウ内で invocation=0 **かつ** artifact=0 が継続している skill は死蔵候補。ただし「保険的価値（明示的な意図シグナル）」を持つ skill は即削除ではなくフォーク扱いとする。telemetry の履歴が浅いときは「データ不足」を明示し、死蔵判定を避ける。バイアスを避けるため、最終判定は general-purpose agent に委譲する。

> telemetry が無いときのフォールバック（jq が無い / 何も溜まっていない）: artifact のプレフィックスを直接数える。例 `ls .ai-context/docs/ | grep -cF "[Audit]"`（少なくとも artifact 側は測る — 呼び出しだけでなく artifact で測る）。

## Axis 3: 最新化（編集リポジトリ ↔ live キャッシュのドリフト）

「編集中のリポジトリ ≠ 実際に動いている plugin」を恒常的に監視する。

検査:
```sh
REPO_VER=$(jq -r '.version' "$PLUGIN"/.claude-plugin/plugin.json 2>/dev/null)
CHANGELOG_VER=$(grep -oE '## \[?[0-9]+\.[0-9]+\.[0-9]+' CHANGELOG.md 2>/dev/null | head -1 | grep -oE '[0-9.]+')
LIVE_VER=$(jq -r '.plugins | to_entries[] | select(.key|startswith("banto@")) | .value[0].version' ~/.claude/plugins/installed_plugins.json 2>/dev/null | head -1)
echo "repo=$REPO_VER  changelog=$CHANGELOG_VER  live-cache=$LIVE_VER"
# Actual skill count vs the number declared in plugin.json
echo "actual skill count: $(ls -d "$PLUGIN"/skills/*/ | wc -l | tr -d ' ')"
grep -oE '[0-9]+ スキル' "$PLUGIN"/.claude-plugin/plugin.json

# 3b. Stale versions piling up in the cache (claude plugin update does not auto-delete old versions)
CACHE_DIR=$(ls -d ~/.claude/plugins/cache/*/banto 2>/dev/null | head -1)
if [ -d "$CACHE_DIR" ]; then
  for v in "$CACHE_DIR"/*/; do
    vv=$(basename "$v")
    [ "$vv" = "$LIVE_VER" ] && continue
    echo "STALE cache version: $vv (not active=$LIVE_VER → deletion candidate)"
  done
fi
```
判定: バージョンが一致しない場合、再同期が必要だと警告する — `claude plugin marketplace update <marketplace> && claude plugin update banto@<marketplace>`、その後 Claude Code を再起動。plugin.json が宣言する skill 数と実数の不一致も指摘する。アクティブでないキャッシュバージョンが残っている場合、「古いバージョンの堆積（無駄な容量）→ `rm -rf` での GC を提案（削除はユーザー確認が必要）」と警告する。

## Axis 4: インストール方針整合（宣言 vs 実態）

plugin.json が「外部に委譲」または「同梱」と宣言しているものが、実環境で実際に成り立っているか。

検査:
```sh
# 4a. Extract delegation declarations from plugin.json (Japanese declaration text)
grep -oE "(完全デリゲート|委譲|delegate)[^」]*" "$PLUGIN"/.claude-plugin/plugin.json
# 4b. 委譲が「自動 install」でなくネイティブ機能（/code-review・/security-review）を指しているか。
#     banto は公式プラグインを自動 install しない（委譲 ≠ install）。install 前提の記述が残っていないか:
grep -rEln "plugin install .*(security-guidance|code-review)" "$PLUGIN" 2>/dev/null
# 4c. 削除済み skill（init-harness 等）への参照が宣言 / kit / カウントに残っていないか
grep -rln "init-harness" "$PLUGIN"/skills "$PLUGIN"/.claude-plugin 2>/dev/null
```
判定: 委譲先が install 前提になっている / 削除済み skill 参照が残る → ドリフト。宣言と実態を一致させる（過去、委譲を install と解釈し自前ガードを消して空白化した事故: v5.16.0 → v5.21.26 復活）。

## Axis 5: Claude 機能整合（現在の挙動との矛盾）

allowed-tools / hook 登録イベント / frontmatter が、現在の Claude Code の挙動またはこの plugin の方針（無効化された機能）と矛盾していないか。

検査:
```sh
# 5a. Skills still listing the disabled AskUserQuestion in allowed-tools
grep -rln "AskUserQuestion" "$PLUGIN"/skills 2>/dev/null
# 5b. Do the hook scripts referenced by hooks.json exist (orphan registration detection)?
jq -r '.hooks[][]?.hooks[]?.command' "$PLUGIN"/hooks/hooks.json 2>/dev/null \
  | sed "s#\${CLAUDE_PLUGIN_ROOT}#$PLUGIN#g" | while read -r h; do
      [ -f "$h" ] || echo "MISSING hook: $h"
    done
# 5c. Do the hooks.json event names exist among the official 29 events (typo detection)?
jq -r '.hooks | keys[]' "$PLUGIN"/hooks/hooks.json 2>/dev/null
```
判定: 無効化された機能の残骸、orphan hook、未知のイベントを is_error として報告する。

---

## 出力（[Audit] レポート）

`.ai-context/docs/[Audit] harness-<YYYY-MM-DD>.md` に保存する。フォーマット:

```
# [Audit] Harness Audit — <date>

## Summary
- Ideology alignment: ✅/⚠/❌ (one-line gist)
- Actual usage: N dead candidates (skill names)
- Freshness: repo=x / cache=y (match or drift)
- Install policy: K of M declarations match reality
- Claude feature alignment: N contradictions

## Details (per axis)
(Each axis's findings + remediation proposals. Critical → High order)

## Remediation actions
- [ ] ... (prioritized)
```

**Critical/High を先に**報告する。是正は提案にとどめ、削除のような破壊的操作は safety.md に従いユーザー確認を要する。
