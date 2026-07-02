#!/bin/sh
# test-ref-scan.sh — ref_scan.py の合成 fixture テスト。
# 検証: xlsx シート棚卸し（名前 / 行数 / ヘッダ / 日本語シート間参照）/ md 抽出 / カード命名 ERE /
#       冪等（source_stat 一致で不変・手書き追記の保全）/ DTD 入り OOXML の拒否（安全側）/ 索引連携。
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SCAN="$SCRIPT_DIR/ref_scan.py"
GEN="$SCRIPT_DIR/store_index_gen.py"

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

command -v python3 >/dev/null 2>&1 || { echo "test-ref-scan: python3 not found — skipped"; exit 0; }

FIX=$(mktemp -d)
trap 'rm -rf "$FIX"' EXIT
SRC="$FIX/src"; BASE="$FIX/base"
mkdir -p "$SRC" "$BASE/docs"

# --- fixture: 2 シート xlsx（日本語シート名・シート間参照・inlineStr ヘッダ）を stdlib で合成 ---
python3 - "$SRC" << 'PYEOF'
import sys, zipfile
from pathlib import Path
src = Path(sys.argv[1])
def sheet(rows): return '<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>' + rows + '</sheetData></worksheet>'
s1 = sheet('<row r="1"><c r="A1" t="inlineStr"><is><t>顧客名</t></is></c><c r="B1" t="inlineStr"><is><t>売上</t></is></c></row><row r="2"><c r="A2"><v>1</v></c><c r="B2"><f>明細!B2*2</f><v>0</v></c></row>')
s2 = sheet('<row r="1"><c r="A1" t="inlineStr"><is><t>品目</t></is></c></row><row r="2"><c r="A2"><v>9</v></c></row><row r="3"><c r="A3"><v>9</v></c></row>')
with zipfile.ZipFile(src / "集計表.xlsx", "w") as z:
    z.writestr("[Content_Types].xml", '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/></Types>')
    z.writestr("_rels/.rels", '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>')
    z.writestr("xl/workbook.xml", '<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="サマリ" sheetId="1" r:id="rId1"/><sheet name="明細" sheetId="2" r:id="rId2"/></sheets></workbook>')
    z.writestr("xl/_rels/workbook.xml.rels", '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/></Relationships>')
    z.writestr("xl/worksheets/sheet1.xml", s1)
    z.writestr("xl/worksheets/sheet2.xml", s2)
# DTD 入りの悪性 OOXML（billion-laughs の前提）— 拒否されること
with zipfile.ZipFile(src / "evil.xlsx", "w") as z:
    z.writestr("[Content_Types].xml", "<Types/>")
    z.writestr("xl/workbook.xml", '<?xml version="1.0"?><!DOCTYPE x [<!ENTITY a "aaaa">]><workbook/>')
PYEOF
printf '# 手順書\n\n## 前提\n\n## 実施\n' > "$SRC/runbook.md"

# --- 1) 走査 ---
python3 "$SCAN" --base "$BASE" --scan "$SRC" >/dev/null 2>&1
N=$(ls "$BASE/docs/refs/" | wc -l | tr -d ' ')
[ "$N" = "3" ] && ok "scan: 3 cards created (xlsx + evil + md)" || fail "scan: cards=$N (want 3)"

CARD=$(ls "$BASE/docs/refs/" | grep "集計表" | head -1)
T="$BASE/docs/refs/$CARD"
grep -q "| サマリ | 2 | 顧客名・売上 | 明細 |" "$T" && ok "xlsx: sheet row (name/rows/headers/ja xref)" || fail "xlsx: sheet table wrong"
grep -q "| 明細 | 3 |" "$T" && ok "xlsx: second sheet inventoried" || fail "xlsx: second sheet missing"

# カード命名 ERE（store-layout の naming と一致）
ls "$BASE/docs/refs/" | grep -vE '^\[Ref\] .+\.md$' >/dev/null && fail "naming: ERE violation" || ok "naming: all cards match ^\\[Ref\\] .+\\.md$"

# DTD 入りは安全側（抽出失敗と明記・スキャンは継続）
EV=$(ls "$BASE/docs/refs/" | grep "evil" | head -1)
grep -q "自動抽出失敗" "$BASE/docs/refs/$EV" && ok "security: DTD-bearing xlsx rejected (fail-safe note)" || fail "security: DTD xlsx not rejected"

# md 抽出
MD=$(ls "$BASE/docs/refs/" | grep "runbook" | head -1)
grep -q "タイトル: 手順書" "$BASE/docs/refs/$MD" && ok "md: title extracted" || fail "md: title missing"

# --- 2) 冪等 + 手書き保全 ---
printf '\n手書きメモ: 重要\n' >> "$T"
python3 "$SCAN" --base "$BASE" --scan "$SRC" > "$FIX/out2" 2>&1
grep -q "unchanged=3" "$FIX/out2" && ok "idempotent: all unchanged on 2nd run" || fail "idempotent: $(cat "$FIX/out2")"
grep -q "手書きメモ: 重要" "$T" && ok "idempotent: hand edits preserved (source_stat unchanged)" || fail "idempotent: hand edits lost"

# ソース更新 → カード再生成
touch "$SRC/集計表.xlsx"
python3 "$SCAN" --base "$BASE" --scan "$SRC" > "$FIX/out3" 2>&1
grep -q "updated=1" "$FIX/out3" && ok "update: touched source regenerates its card" || fail "update: $(cat "$FIX/out3")"

# --- 3) 索引連携（カードが doc_type=ref で載る） ---
python3 - << 'PYEOF' > /dev/null 2>&1 || exit 0
import sqlite3; sqlite3.connect(":memory:").execute("CREATE VIRTUAL TABLE t USING fts5(x, tokenize='trigram')")
PYEOF
if command -v sqlite3 >/dev/null 2>&1; then
    python3 "$GEN" --base "$BASE" --force >/dev/null 2>&1
    NREF=$(sqlite3 "$BASE/.store-index.db" "SELECT count(*) FROM docs WHERE doc_type='ref'" 2>/dev/null)
    [ "$NREF" = "3" ] && ok "index: 3 ref cards indexed (doc_type=ref)" || fail "index: ref docs=$NREF"
fi

echo ""
echo "test-ref-scan: $PASS passed, $FAIL failed"
[ "$FAIL" = "0" ] || exit 1
exit 0
