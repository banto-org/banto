# Banto（番頭）

**Claude Code のための自走ハーネス。** あなたは方針を決めるだけ — 開発は番頭が回します。

番頭とは、商家の主人に代わって店のすべてを切り盛りし、例外だけを主人に上げる筆頭奉公人のこと。
Banto はその契約を AI 駆動開発に持ち込みます — あなたの思想・決定・知識を保持して Claude に食わせ、
自走する。例外は checkpoint として上がってくる。安全は約束ではなく**決定論的な hook** が守る。

[English README](README.md)

> **Status: beta。** Banto 自身の開発で毎日 dogfood していますが、公開パッケージとしては
> 若いプロダクトです。issue / PR 歓迎 — [CONTRIBUTING.md](CONTRIBUTING.md) を参照。

## 何が手に入るか

- **SDD パイプライン** — `concept`（思想）→ `spec`（業界標準の設計書）→ 自走実装。
  `dev-loop` が自走ビルドループ（分解 → 実装 → 検証 → 修正を緑になるまで・例外だけ owner へ）を駆動。
  思想層は CLAUDE.md に注入され、全エージェントの判断フィルタになります
- **セッションを跨いで生きる AI コンテキスト** — 決定ログ / リサーチ / タスク / checkpoint を
  中央ナレッジ store（`~/ai-context-store/<project>/`）に保存し、セッション開始時に再注入。
  **repo は汚れません** — 知識は store へ、code は repo へ。蓄積した知識への Claude ネイティブ
  内部検索（クエリ展開 + ランキング）。store layout は外部ツール向けの安定した read 契約:
  [ディレクトリ構造](plugins/banto/i18n/ja/skills/ai-context/references/directory-structure.md)
- **決定論的な安全 hook** — kill-switch（main 直 push / `--no-verify` / force-push の block）、
  egress guard（内部名・PII の客先成果物への流出を名前レジストリ駆動で block）、
  verify-before-claim（検証なしの「完了」発言を block）
- **任意の OS サンドボックス（opt-in）** — hook の下に敷くもう一段の決定論的な層。Claude の bash を
  OS サンドボックス（macOS Seatbelt / Linux・WSL2 bubblewrap）の中で走らせ、秘匿ディレクトリ
  （`~/.ssh`・`~/.aws` 等）の読取と、許可ドメイン（github / npm / pypi / anthropic）以外の outbound を
  block。**既定は off** — `harness-setup.sh` は無効状態の hardening ブロックを配置するだけで、
  settings.json の `sandbox.enabled: true` で有効化。影響は Claude の bash のみ（あなたの手動
  ターミナル・権限プロンプトは不変）。egress guard と二層の defense in depth。
  詳細: [サンドボックスのドキュメント](https://code.claude.com/docs/ja/sandboxing)
- **ワークスペースと艦隊運用** — トピック別ワークスペース + 3 階層ブランチ（main ← epic ←
  task worktree、git-town 委譲）、並走セッションの registry と衝突検知
- **自己監査** — 14 軸の plugin 品質監査（content-hygiene 検査込み）+ 宣言と実体の乖離を見張る
  5 軸ハーネス監査
- **日本語が正本・言語は切り替え式** — スキルとエージェントは日本語で書き、英語版はそこから生成して
  ズレ検査で同期。`/set-language ja|en` で実際に動くセットを片方の言語に切り替える。選択はプラグイン更新をまたいで保持。公開既定は英語。

14 skill / 6 agent / 38 hook / 9 rule。MCP 同梱なし。セキュリティレビュー・コードレビューは
**Anthropic 公式 plugin への完全委譲**（再実装しない方針）。

## 必要なもの

- [Claude Code](https://code.claude.com/)（CLI またはデスクトップ）
- `git`、`jq`（必須）— `gh` / `git-town` / `python3` があると追加機能が有効化
  （author 検出・3 階層ブランチ・egress guard / Web 本文抽出）。無くても全機能が graceful に縮退

macOS / Linux 対応。Windows は Git Bash（Git for Windows 同梱）上で動作 — 静的監査済み・実機検証は未了。
既知の制約:

- Windows でも `jq` は必須 — 無いと全 hook が黙って no-op になります（`winget install jqlang.jq`）
- python3 依存機能（PII egress guard・検索インデックス再構築）は無ければ graceful にスキップ
- Obsidian vault 連携は macOS 専用（他 OS では明示メッセージを出して終了）
- ファイル編集時の hook がバックグラウンドプロセスを起動するため、Windows ではやや遅延します

## インストール

```bash
claude plugin marketplace add banto-org/banto
claude plugin install banto@banto-marketplace
```

Claude Code を再起動します。CLAUDE.md の無いプロジェクトでは SessionStart hook が正確なコマンド
付きで初回セットアップを提案します。ユーザーレベルのハーネスセットアップを自分で走らせる場合:

```bash
sh "$(ls -d ~/.claude/plugins/cache/*/banto/*/ | sort -V | tail -1)scripts/harness-setup.sh"
```

この決定論スクリプトが行動規範 rules・statusline・最小限の permissions・**無効状態の OS サンドボックス
ブロック**（opt-in。`sandbox.enabled: true` で有効化）の配布と、中央ナレッジ store の初期化までを
行います（`--plan` で適用せずプレビュー）。CLAUDE.md は**ネイティブ `/init`**
が生成し、プロジェクト側 rules は `harness-setup.sh --project` で配置します。コードレビューと
セキュリティレビューはネイティブの `/code-review` / `/security-review` に委譲します（banto は
再実装も自動インストールもしません）。中央ナレッジ store は**初回に一度だけ対話で**ブートストラップ
します（黙ってローカル store を作らず、repo の初回セッションで SessionStart hook が確認します。既存の
GitHub `ai-context-store` を登録するか／どの org に新規作成するか／ローカルのみか。選んだ org は以降の
プロジェクトに再利用されます）。チーム運用時のみ store の git 同期を設定します。

## 日本語で使う（公開既定は英語）

skill / agent の表示を日本語に切り替えるには、**一度だけ**次を実行する:

```
/set-language ja
```

その後 **Claude Code を再起動**すると日本語セットがロードされる。選択は永続化され、**プラグイン更新をまたいで保持**されるので、**以降この操作は不要**（英語へ戻すときだけ `/set-language en` ＋ 再起動）。

## 使い心地

コマンドを覚える必要はありません — 自然文が主経路で、コマンドはエイリアスです:

| あなたの発話 | Banto の動き |
|---|---|
| 「決済のリデザインを始める」 | epic ブランチ + ワークスペースを開く |
| 「X を調べて」 | research agent が並列調査 → ナレッジ store（`docs/research/`）に保存 |
| 「認証って前に決めたっけ」 | 決定ログ・履歴への内部検索 |
| 「この作業終わった」 | テスト → epic へマージ → sync → 掃除 |
| 「main に入れて」 | PR 作成 — **不可逆・外向き操作は必ず人間ゲートで止まる** |

## 思想（短縮版）

- **承認ゲートではなく自走** — 強制は hook に、承認は最小限に
- **約束より決定論** — 起きてはならないことは prompt でなく hook が block する
- **lean** — 枯れた仕組み（git-town・公式 plugin）に委譲し、車輪を再発明しない
- **測って、畳む** — telemetry が skill の使用度を記録し、死蔵機能は削除される

思想の全文: [CONCEPT.md](CONCEPT.md)

## NDA 下で開発するチームへ

Banto は「内部名がひとつ客先成果物に漏れたらインシデント」という受託開発の現場で生まれました。
egress guard はレジストリ記載の名前の客先パスへの書き込みを block し、名前レジストリは
user スコープに置かれて決してコミットされず、content-hygiene 監査がドキュメント内の
固有参照・貼り込み残骸を検出します。

## ライセンス

[MIT](LICENSE)
