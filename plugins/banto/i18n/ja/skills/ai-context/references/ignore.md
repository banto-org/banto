# /ai-context ignore — denylist 管理詳細

## 目的

`banto` の SessionStart / UserPromptSubmit hook は、git work tree 内のプロジェクトで中央 store 側に project skeleton を自動 scaffold する（store-first: repo 内には何も作らない）。試作・他人のリポジトリ・一時作業ディレクトリ等、store に登録したくないプロジェクトを、ユーザー側でパス単位に抑止する。

denylist ファイル: `~/.claude/banto-ignore`
（環境変数 `BANTO_IGNORE_FILE` で上書き可）

ファイル形式:
- 1 行 1 パス
- `#` で始まる行はコメント、空行は無視
- `~` / `~/` は `$HOME` に展開
- 行末コメント（` #` の前にスペース必須）も許容
- マッチング: プレフィックスマッチ（CWD == path もしくは CWD が path 配下）

## サブサブコマンド

`$ARGUMENTS` の 2 トークン目を処理する。

- 空 → list を実行 + メニュー（add 現在パス / add 任意 / remove）を案内
- `list`        → 一覧表示（行番号付き）
- `add`         → 現在の CWD を追加（`pwd` の絶対パス）
- `add <path>`  → `<path>` を絶対パスに正規化して追加
- `remove`      → list 表示後、対話的に番号入力
- `remove <N>`  → 行番号 N （1-indexed、有効行のみ）を削除

## 共通: ファイル準備

```bash
IGNORE_FILE="${BANTO_IGNORE_FILE:-$HOME/.claude/banto-ignore}"
mkdir -p "$(dirname "$IGNORE_FILE")"
[ -f "$IGNORE_FILE" ] || cat > "$IGNORE_FILE" <<'EOF'
# banto ignore list
# 1 行 1 パス、# でコメント、~/ は $HOME に展開
EOF
```

## list 実装

```bash
awk 'BEGIN{n=0}
     /^[[:space:]]*$/{next}
     /^[[:space:]]*#/{next}
     {n++; sub(/[[:space:]]+#.*$/,""); sub(/^[[:space:]]+/,""); sub(/[[:space:]]+$/,"")
      printf "%d\t%s\n", n, $0}' "$IGNORE_FILE"
```

出力例:
```
登録済み除外パス（~/.claude/banto-ignore）:
  1  /Users/you/scratch
  2  ~/Documents/clients/foo
  3  /tmp/sandbox

合計: 3 件
```

0 件なら「（登録なし）」と表示。

## add 実装

引数なし: `TARGET=$(pwd)`

引数あり:
```bash
RAW="$1"
case "$RAW" in
  '~') TARGET="$HOME" ;;
  '~/'*) TARGET=$(printf '%s' "$RAW" | sed "s|^~/|$HOME/|") ;;
  /*) TARGET="$RAW" ;;
  *) TARGET="$(cd "$RAW" 2>/dev/null && pwd)" || { echo "エラー: パスが解決できません: $RAW"; exit 1; } ;;
esac
TARGET="${TARGET%/}"
```

`~/` 展開は `${RAW#~/}` では zsh 等で意図通り動かないため、sed 経由で確実に置換する。

重複チェック:
```bash
if grep -Fxq "$TARGET" "$IGNORE_FILE" 2>/dev/null; then
    echo "既に登録されています: $TARGET"
    exit 0
fi
```

追加:
```bash
[ -s "$IGNORE_FILE" ] && [ "$(tail -c1 "$IGNORE_FILE" | xxd -p)" != "0a" ] && echo "" >> "$IGNORE_FILE"
echo "$TARGET" >> "$IGNORE_FILE"
echo "追加しました: $TARGET"
echo ""
echo "次セッション以降、このパス（および配下）で banto の自動 store scaffold が抑止されます。"
echo "既に store 側に作られた project dir は変更されません（不要なら手動で削除してください）。"
```

## remove 実装

引数あり（数値）: list の有効行番号 N に対応する原文行を特定して削除（コメント行の上下関係は保持）

引数なし:
1. list を表示
2. テキストで「削除する番号は？（カンマ区切りで複数指定可、cancel で中止）」と確認
3. 入力をパースして該当行を削除（多重削除は行番号が大きい方から処理）

実装の擬似コード:
```bash
remove_by_index() {
    target_n="$1"
    awk -v target="$target_n" '
        BEGIN{n=0}
        /^[[:space:]]*$/{print; next}
        /^[[:space:]]*#/{print; next}
        {n++; if (n != target) print}
    ' "$IGNORE_FILE" > "$IGNORE_FILE.tmp" && mv "$IGNORE_FILE.tmp" "$IGNORE_FILE"
}
```

## 引数なし（メニュー）

```
登録済み除外パス（~/.claude/banto-ignore）:
  1  /Users/you/scratch
  2  ~/Documents/clients/foo

操作:
  /ai-context ignore add            ← 現在の CWD（{pwd}）を追加
  /ai-context ignore add <path>     ← 任意パスを追加
  /ai-context ignore remove <N>     ← 行番号 N を削除
  /ai-context ignore list           ← 一覧表示
```

## 安全ルール

- 既に store 側に作られた project dir は ignore add で削除しない（抑止は新規 scaffold のみ）
- denylist 編集はテキスト追記/削除のみ。既存コメントは保持
