# 監査 7 軸

各軸に判定手順（機械的に追える 2〜4 ステップ）・合格基準・典型的な違反例を 1 つずつ示す。機械計測は `scripts/skill-audit-metrics.sh` の出力（procedure.md 参照）を使う。

## A1: 情報の最小性

実行に不要な情報（経緯・背景語り・自明な一般論）が SKILL.md に無いかを見る。

判定手順:
1. SKILL.md 本文を Read し、段落ごとに「実行判断か手順のどちらに寄与するか」を問う
2. 寄与しない段落（沿革説明・一般論の前置き）を洗い出す
3. `skill-audit-metrics.sh` の行数・バイト数と、実質手順数を突き合わせ、密度を見る

合格基準: 本文の各段落が判断材料か実行手順のいずれかに寄与する。実行に不要な段落が無い。

典型的な違反例: 「このスキルは旧スキルを統合して作られた」のような沿革説明が本文に残っている。

## A2: 人間専用情報の混入

変更履歴・作者メモ・TODO・経緯メタ情報が無いかを見る（ja-lint.py の検出パターンと同一群）。

判定手順:
1. `skill-audit-metrics.sh` の経緯メタ情報パターンヒット行（「（最新）」「（新規）」「新規追加」「今回追加」「従来は」「から変更」「旧版では」）を確認する
2. ヒット行が正本の記述として必要か、編集履歴の残骸かを判定する
3. TODO・作者メモ・レビューコメント調の文（「〜した方がいい」等）を目視で追加確認する

合格基準: 変更履歴・作者メモ・TODO・経緯メタ情報が本文に無い。

典型的な違反例: 「（2026-07 追加）」のような日付付き注記が本文に残る。

## A3: 構成の分担

SKILL.md はルーター（いつ使うか / references の選び方）に徹しているか、references 間・SKILL.md 間で同一情報の重複記載が無いかを見る。

判定手順:
1. SKILL.md が「いつ使うか」と「どの references を読むか」の道案内に徹しているか確認する
2. `skill-audit-metrics.sh` の重複段落検出（正規化 30 字以上行の複数ファイル一致）を実行する
3. 重複がヒットしたら、SKILL.md 本体と references のどちらを正本にするか判定し、他方を要約 + リンクへ縮める

合格基準: SKILL.md と references 間、references 相互間で同一情報の重複記載が無い。SKILL.md が実質手順を丸ごと抱えていない。

典型的な違反例: SKILL.md 本体と `references/procedure.md` の両方に同じ実行手順が全文書かれている。

## A4: 実行モデル指定の適切さ

odd.yaml の宣言、Agent 起動を含む skill なら model 指定の有無と `templates/model-policy.json` との整合を見る。

判定手順:
1. odd.yaml の autonomy_level 宣言を確認する（L0〜L3 の範囲内か）
2. skill が Agent 起動を含むか（allowed-tools に Agent があるか）を確認する
3. Agent 起動を含む場合、`skill-audit-metrics.sh` の model 指定抽出結果（`model:` / `model=` 行）を確認する
4. model-policy.json（roles: design=inherit / implement=sonnet / mechanical=haiku / audit=opus）と役割が整合するか照合する

合格基準: Agent 起動箇所に役割に応じた model 指定がある（判定系は opus、実装系は sonnet、機械的検索は haiku）。odd.yaml の autonomy_level が L0〜L3。

典型的な違反例: 判定系の Agent 起動に model 指定が無く、既定モデルに委ねている。

## A5: コンテキスト効率

frontmatter description の質、本文トークン量に対する情報密度、references が段階的開示になっているかを見る。

判定手順:
1. frontmatter description がトリガー語を含み、概ね 1,024 字以内かを確認する
2. `skill-audit-metrics.sh` の本文バイト数・行数から情報密度を見る（同じ情報量に対して長すぎないか）
3. references が SKILL.md から明示的にリンクされ、必要時にだけ読まれる構成になっているか確認する

合格基準: description がトリガー語を含み文字数上限内。本文が references へ分割すべき分量を SKILL.md に抱えていない。

典型的な違反例: description が抽象的すぎてトリガー語が無く、どんな発言で起動するか分からない。

## A6: 想定 AI の明示と整合

対象ホスト / モデルの想定を確認する。明示が無ければ Claude（Claude Code）前提とみなし、それで整合していれば合格。「汎用」を明示する skill は Claude 固有の記述が残っていれば違反。

判定手順:
1. skill 本文に対象ホスト / モデルの明示（「汎用」「ChatGPT」「他の AI」等）があるか確認する
2. 明示が無ければ Claude（Claude Code）前提とみなす
3. 「汎用」を明示する skill の場合、`skill-audit-metrics.sh` の Claude 固有トークン出現数（Task / Skill / CLAUDE_PLUGIN_ROOT / hook 等）を確認する
4. 明示と本文の記述が整合しているか判定する（主観判定は Agent に委譲）

合格基準: 明示が無い skill は、Claude 固有の記述（ツール名 Task/Skill、`${CLAUDE_PLUGIN_ROOT}`、hook 前提）で整合していれば合格。「汎用」明示の skill は Claude 固有トークンが残っていれば違反。

典型的な違反例: 「汎用スキル、どの AI でも使える」と明記しながら、本文に `${CLAUDE_PLUGIN_ROOT}` や hook 前提の記述が残っている。

## A7: 決定論との分担

skill の散文が約束している安全・品質規律のうち、hook で強制すべき / 既に強制済みのものが区別されているかを見る。

判定手順:
1. skill の散文が約束している安全・品質規律（「必ず」「禁止」等の強制表現）を洗い出す
2. その規律が既存の hook（例: egress-guard.sh / lint-guard.sh / odd-kill-switch.sh）で既に強制されているか照合する
3. hook 未カバーの強制表現があれば、hook 化候補として指摘する

合格基準: skill が「必ず〜する」と書く安全規律のうち、hook で強制可能なものは対応する hook 名を明示して区別されている。強制と提案が混同されていない。

典型的な違反例: 「シークレットを絶対に出力しない」と skill 本文に書きながら、対応する hook（egress-guard.sh 等）への言及が無い。
