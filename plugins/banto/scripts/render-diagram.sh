#!/bin/sh
# render-diagram.sh — .mmd / .drawio を SVG にレンダする
# usage: render-diagram.sh <input.mmd|input.drawio> [output.svg]
# 出力先パスを stdout に返す。レンダ手段が無ければ exit 1（呼び出し側でフォールバック判断）
set -eu

[ $# -ge 1 ] || { echo "usage: render-diagram.sh <input.mmd|input.drawio> [output.svg]" >&2; exit 2; }
in="$1"
[ -f "$in" ] || { echo "input not found: $in" >&2; exit 2; }
out="${2:-${in%.*}.svg}"

case "$in" in
  *.mmd|*.mermaid)
    # 複数SVGを1つのHTMLにインラインしても衝突しないよう、ファイル名由来の id を付与
    svgid="mmd-$(basename "${out%.*}" | tr -c 'a-zA-Z0-9' '-' | sed 's/-*$//')"
    if command -v mmdc >/dev/null 2>&1; then
      mmdc -i "$in" -o "$out" -b transparent -I "$svgid" --quiet
    elif command -v npx >/dev/null 2>&1; then
      # 初回は puppeteer の Chromium ダウンロードで数分かかる（以後キャッシュ）
      npx -y @mermaid-js/mermaid-cli -i "$in" -o "$out" -b transparent -I "$svgid" --quiet
    else
      echo "mermaid-cli が見つかりません: npm i -g @mermaid-js/mermaid-cli するか npx を用意してください" >&2
      exit 1
    fi
    ;;
  *.drawio)
    app="/Applications/draw.io.app/Contents/MacOS/draw.io"
    if command -v drawio >/dev/null 2>&1; then
      drawio -x -f svg -o "$out" "$in" >/dev/null 2>&1
    elif [ -x "$app" ]; then
      "$app" -x -f svg -o "$out" "$in" >/dev/null 2>&1
    else
      echo "draw.io CLI が未導入です（brew install --cask drawio）。.drawio をそのまま併納する経路に切り替えてください" >&2
      exit 1
    fi
    ;;
  *)
    echo "unsupported input (expected .mmd / .mermaid / .drawio): $in" >&2
    exit 2
    ;;
esac

[ -f "$out" ] || { echo "render failed: $out が生成されていません" >&2; exit 1; }
echo "$out"
