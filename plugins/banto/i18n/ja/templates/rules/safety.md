# 変更安全性ルール

AI 全般の行動規範（常時適用）。lockfile / マニフェストの編集制約は `dependencies.md`（path-scoped）に分離。

## 操作の安全性

- ファイル編集・テスト実行・ローカル操作 → 自由に実行してよい
- ファイル削除・git push・PR 作成・外部サービスへの投稿 → 事前にユーザーへ確認する。会話内での承認があれば十分 — 一度ユーザーが承認したら、再確認なしに実行する。リポジトリ単位の常設承認は ai-context store の grants ファイル（`{base}/meta/grants.json`、キー: `pr_create` / `push_feature` / `prod_ops`）に記録できる。そこでの `allow` はそのリポジトリに対するユーザーの確認とみなす（`release-guard.sh` / `prod-guard.sh` が強制）
- --no-verify・force-push・main/master への直接 push → 禁止
  - 例外: ai-context ナレッジストア（リポジトリルートに `.ai-context-store` マーカーを持つリポジトリ）は main への直接 push を許可
    push ポリシーはコードリポジトリ（PR-gated）と分離している — 既存の kill-switch と同じマーカー確認
    この例外はマーカーを持つ store パスに限定され、コードリポジトリには一切及ばない
- 他者が作成した PR を自分でマージしない。ユーザーから明示的な許可があっても、自分では実行せず、ユーザー自身にマージさせる
- 本番環境操作（デプロイ・prod DB / インフラ変更）→ 既定でブロック（`prod-guard.sh`）。会話内承認（エスケープ）または常設 `prod_ops: allow` grant がある場合のみ許可

## シークレット保護

- .env・credentials・シークレットを絶対にコミットしない
- .env / credentials / API キーを含むファイルを、ターミナルやチャットで生の `cat` / `diff` / `grep` 出力として表示しない。値は必ずマスクする:
  - 値が必要な場合: `sed 's/=.*/=***/'` でキー名のみ出力する
  - diff チェック: `diff` で比較する前に両側をマスクする
  - grep 対象: `grep "^AWS_"` のようにプレフィックスへ絞り込み、トークン（`HF_TOKEN`, `GH_TOKEN`, `*_API_KEY`, `*_SECRET`, `Bearer *`）を巻き込まないようにする
  - バックアップファイル（`.env.old` 等）は役目を終え次第削除する
- **デバッグに `bash -x`、`set -x`、`env`、`set`、`declare -p`、`printenv` を絶対に使わない** — source した `.env` の値がトレースに漏れ、チャット履歴に残る。代わりに:
  - 個々の変数を明示的にマスクして echo する（`echo "KEY=[${#VAR} chars]"`）
  - またはシークレットを含まないスタブ `.env` を一時的に使う（`MY_API_KEY=dummy bash script.sh ...`）
- シークレットが露出した場合は直ちにユーザーへ通知し、revoke / rotation を強く推奨する（チャット履歴に残り続けるため）
