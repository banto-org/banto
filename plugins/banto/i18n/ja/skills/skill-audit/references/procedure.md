# 監査の実行手順

## 1. 対象の特定

`$ARGUMENTS` または会話文脈から対象 skill のディレクトリを特定する。`<dir>/SKILL.md` が実在することを確認する。実在しなければユーザーに確認する。

## 2. 機械計測の取得

```sh
sh "$CLAUDE_PLUGIN_ROOT/scripts/skill-audit-metrics.sh" <skill-dir>
```

出力:
- (a) SKILL.md / 各 reference のバイト数・行数
- (b) frontmatter description の文字数
- (c) 経緯メタ情報パターン（ja-lint.py の META_PATTERNS と同一群）のヒット行
- (d) ファイル間の重複段落（正規化した 30 字以上の行が複数ファイルに一致するもの、対象ファイル名付き）
- (e) Claude 固有トークン（Task / Skill / CLAUDE_PLUGIN_ROOT / hook / allowed-tools / SKILL.md）の出現数
- (f) model 指定（`model:` / `model=`）の抽出行

## 3. 7 軸の判定

[`axes.md`](axes.md) の各軸の判定手順に沿って、機械計測 + Read した SKILL.md / references の内容を突き合わせる。A6（想定 AI の明示と整合）のような主観の入る判定は、Agent（general-purpose。モデル選定はメイン AI の判断）に委譲する（Reviewer = Fresh Agent 原則）。委譲プロンプトには TARGET の SKILL.md・references/ 全ファイル・scripts/（docstring と構造）を Read する指示を必ず含める — SKILL.md 単体の監査は references に埋まる違反（壊れた参照・重複・経緯メタ）を見逃す。

## 4. 報告

軸ごとに PASS / WARN / FAIL + 根拠となる行番号 + 修正案 1 文で報告する。結論を先に置き、数字は実数で示す。

```
# Skill Audit: <skill-name>

## Summary
- A1 情報の最小性: PASS/WARN/FAIL
- A2 人間専用情報の混入: PASS/WARN/FAIL
- A3 構成の分担: PASS/WARN/FAIL
- A4 実行モデル指定: PASS/WARN/FAIL
- A5 コンテキスト効率: PASS/WARN/FAIL
- A6 想定 AI の明示と整合: PASS/WARN/FAIL
- A7 決定論との分担: PASS/WARN/FAIL

## 詳細（軸ごと）
(各軸の根拠行番号 + 修正案)
```

## 5. 修正の適用

指摘の適用はユーザー承認後に行う。監査自体は read-only（Bash は `skill-audit-metrics.sh` の実行のみ）。
