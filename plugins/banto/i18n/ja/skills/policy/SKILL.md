---
name: policy
description: |
  **UTILITY SKILL** — repo 別ポリシー正典（`{store}/{project}/meta/policy.json` = grants + ignore）を 1 画面の GUI で一覧・編集する policy console。変更はその場で自動保存され hook に即時反映、store への commit + 同期も自動。サーバは「完了して閉じる」ボタン・タブを閉じる・15 分の放置のいずれかで自動終了する（常駐しない）。会話からの変更も同じ policy.json を編集する（同一正典）。
  トリガー: 「ポリシー見せて」「許可一覧」「ignore 設定」「policy console」「どこまで許可してるか」。/policy でも起動可。
  使わない場面: 会話での単発の grants 変更（ai-context skill の grants 管理で足りる）。
user-invocable: true
allowed-tools: Read Edit Write Bash
compatibility: Claude Code (requires python3, git)
---

# Policy Console

repo 別ポリシー正典は `{store}/{project}/meta/policy.json`:

```json
{"grants": {"pr_create": "allow"}, "ignore": {"no_edit": ["*.env"], "no_sync": ["private/**"]}}
```

- `grants`（pr_create / pr_merge / push_feature / prod_ops + 任意キー）は release-guard / prod-guard が解決する。値は `allow` / `confirm` / `deny`（欠落は confirm）。時限 object 形式 `{"value": "allow", "until": "YYYY-MM-DD"}` も可。旧 `meta/grants.json` へ fallback
- `ignore.no_edit` は policy-guard.sh（編集ブロック）、`ignore.no_sync` は ai-context-sync.sh（store の `.git/info/exclude`）が強制する
- 対象 store は `~/.claude/banto-ai-context-stores`（1 行 1 store パス）、無ければ `~/ai-context-store`

## 起動（一覧と編集は同じ 1 画面）

Bash を `run_in_background=true` で起動し、stdout に出る URL（トークン付き）を `open` で開く:

```bash
# 1) バックグラウンドで起動（stdout に URL が 1 行出る）
python3 "$CLAUDE_PLUGIN_ROOT/scripts/policy-console.py"
# 出力例: http://127.0.0.1:53201/?t=XXXX

# 2) 出力された URL をそのまま開く
open "http://127.0.0.1:53201/?t=XXXX"
```

画面の挙動（ユーザーに伝えること）:

- **変更は自動保存**。保存ボタンはなく、セレクトやパターン欄を変えるとその場で policy.json に書かれ、hook には即時に効く。store への commit + 同期は数秒後に自動で走る
- **Claude Code 層カード（画面最上部）**: `Bash(gh pr merge:*)` + `Bash(gh pr checks:*)` を `~/.claude/settings.json` の permissions.allow へ 1 クリックで追加 / 除去する（書き込み前に settings.json.bak へバックアップ）。これは層 1（コマンド種別の全 repo 共通許可）で、実際に通るかは層 2 = repo 別 grants の `pr_merge` が決める。**この書き込みの引き金は人間のクリックだけ** — AI の自己許可をブロックする Claude Code の設計と整合させるための分担であり、AI がこのファイルを直接編集してはならない
- **サーバは常駐しない**。右上「完了して閉じる」で画面とサーバの両方が終了する。タブを閉じても数秒後に自動終了、放置しても 15 分で自動終了（`--idle-timeout 秒` で変更、0 で無効）
- 127.0.0.1 束縛 + ランダムトークン必須（不一致は 403）。URL は起動ごとに変わる
- grants.json しか無い project は変更時に policy.json を新規作成する（grants.json は残す）

自動終了するため KillShell は通常不要。ユーザーが「開いたままにして」と言った場合のみ `--idle-timeout 0` で起動する。

## 会話からの変更（GUI と同一正典）

GUI を開かず変更する場合も、編集対象は同じ policy.json:

1. `{store}/{project}/meta/policy.json` を Read → Edit（無ければ grants.json の grants を取り込んで新規作成。grants.json は残す）
2. `sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-context-sync.sh" <store>` で store へ同期
