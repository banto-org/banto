#!/usr/bin/env python3
"""ref_scan.py — 外部ディレクトリを走査して [Ref] 所在カードを {base}/docs/refs/ に一括生成（決定論・冪等）。

decision 2026-07-02-234512（所在カード + 相関グラフ）Phase 1.5。LLM を使わない決定論層のみ:
- xlsx: シート一覧（名前 / 行数 / ヘッダ実テキスト）+ シート間の数式参照 + 外部ブック参照
- csv: ヘッダ行 / md: タイトル + 見出し / docx: 見出し段落 / その他: サイズ・更新時刻のみ
- 冪等: frontmatter source_stat（size:mtime_ns）が一致するカードは書き換えない
- 意味要約・store 文書との相関付け（related:）は Phase 2（LLM 判定層）— 本スクリプトは触らない
  （既存カードの手書き/モデル追記の related: と本文は、source_stat 不変なら保全される）

Usage: ref_scan.py --base <project base> --scan <dir> [--max N]
"""
import argparse
import datetime
import os
import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

XNS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
       "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships"}
WNS = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
SKIP_DIR = {".git", ".svn", "node_modules", "__pycache__", ".Trash"}
MAX_SHEET_ROWS_LIST = 40  # カードに載せるシート数の上限（100 シート級はサマリ行を付す）
MAX_XML_BYTES = 50 * 1024 * 1024  # zip 展開後の単一 XML 上限（zip bomb 対策）


def _fromstring(data: bytes):
    """信頼できない OOXML パートの安全な parse。正規の OOXML に DOCTYPE は現れないため、
    DTD（billion-laughs / XXE の前提）を含む XML と過大な XML は拒否する（stdlib のみで決定論的）。"""
    if len(data) > MAX_XML_BYTES:
        raise ValueError("xml part too large")
    if b"<!DOCTYPE" in data[:4096] or b"<!ENTITY" in data:
        raise ValueError("DTD/ENTITY in OOXML part (rejected)")
    return ET.fromstring(data)


def _cell_text(c, sst):
    t = c.get("t")
    if t == "inlineStr":
        el = c.find("m:is/m:t", XNS)
        return el.text or "" if el is not None else ""
    v = c.find("m:v", XNS)
    if v is None or v.text is None:
        return ""
    return sst[int(v.text)] if t == "s" and sst and v.text.isdigit() else v.text


def scan_xlsx(fp: Path):
    """シート一覧 / 行数 / ヘッダ / シート間参照 / 外部ブック参照（stdlib のみ・実証 2026-07-03）"""
    z = zipfile.ZipFile(fp)
    wb = _fromstring(z.read("xl/workbook.xml"))
    sheets = [(s.get("name"), s.get("{%s}id" % XNS["r"])) for s in wb.findall(".//m:sheet", XNS)]
    try:
        sst = ["".join(t.text or "" for t in si.findall(".//m:t", XNS))
               for si in _fromstring(z.read("xl/sharedStrings.xml")).findall("m:si", XNS)]
    except KeyError:
        sst = []
    rid2path = {}
    try:
        rels = _fromstring(z.read("xl/_rels/workbook.xml.rels"))
        for rel in rels:
            t = (rel.get("Target") or "").lstrip("/")
            rid2path[rel.get("Id")] = t if t.startswith("xl/") else "xl/" + t
    except KeyError:
        pass
    rows_out, ext = [], set()
    for name, rid in sheets:
        path = rid2path.get(rid, "")
        try:
            sx = _fromstring(z.read(path))
        except (KeyError, ET.ParseError):
            rows_out.append((name, "?", [], []))
            continue
        rows = sx.findall(".//m:sheetData/m:row", XNS)
        headers = []
        if rows:
            headers = [h for h in (_cell_text(c, sst) for c in rows[0].findall("m:c", XNS)[:8]) if h][:6]
        xrefs = set()
        for fml in sx.findall(".//m:f", XNS):
            # 'クォート付きシート名'! と 素のシート名!（日本語等の非 ASCII を含む）の両形
            for q, b in re.findall(r"'([^']+)'!|([^\s'!,()=+\-*/:;&\"]+)!", fml.text or ""):
                ref = q or b
                if ref and ref != name:
                    xrefs.add(ref)
        rows_out.append((name, str(len(rows)), headers, sorted(xrefs)[:6]))
    # 外部ブック参照（externalLinks の rels ターゲット）
    for n in z.namelist():
        if n.startswith("xl/externalLinks/_rels/"):
            try:
                for rel in _fromstring(z.read(n)):
                    ext.add(Path(rel.get("Target") or "").name)
            except ET.ParseError:
                pass
    return rows_out, sorted(ext)


def scan_docx(fp: Path):
    z = zipfile.ZipFile(fp)
    doc = _fromstring(z.read("word/document.xml"))
    heads = []
    for p in doc.iter("{%s}p" % WNS["w"]):
        st = p.find(".//w:pPr/w:pStyle", WNS)
        if st is None:
            continue
        val = st.get("{%s}val" % WNS["w"]) or ""
        if val.lower().startswith("heading") or val.startswith("見出し"):
            txt = "".join(t.text or "" for t in p.findall(".//w:t", WNS)).strip()
            if txt:
                heads.append(txt)
        if len(heads) >= 15:
            break
    return heads


def scan_csv(fp: Path):
    with fp.open("r", errors="replace") as fh:
        header = fh.readline().strip()
    return header[:200]


def scan_md(fp: Path):
    text = fp.read_text(errors="replace")
    m = re.search(r"^#\s+(.+)$", text, re.M)
    heads = re.findall(r"^##\s+(.+)$", text, re.M)[:10]
    return (m.group(1).strip() if m else ""), heads


def card_name(fp: Path) -> str:
    base = re.sub(r'[/\\:*?"<>|]', "_", fp.stem)[:80]
    import hashlib
    h = hashlib.sha256(str(fp).encode()).hexdigest()[:6]
    return f"[Ref] {base}-{h}.md"


def build_body(fp: Path, kind: str) -> str:
    lines = []
    if kind == "xlsx":
        sheets, ext = scan_xlsx(fp)
        lines.append(f"## シート一覧（自動棚卸し・{len(sheets)} シート）")
        lines.append("")
        lines.append("| シート | 行数 | ヘッダ | シート間参照 |")
        lines.append("|---|---|---|---|")
        for name, n, headers, xrefs in sheets[:MAX_SHEET_ROWS_LIST]:
            lines.append(f"| {name} | {n} | {'・'.join(headers)} | {'・'.join(xrefs)} |")
        if len(sheets) > MAX_SHEET_ROWS_LIST:
            lines.append(f"| …（残り {len(sheets) - MAX_SHEET_ROWS_LIST} シート省略） | | | |")
        if ext:
            lines.append("")
            lines.append(f"外部ブック参照: {', '.join(ext)}")
    elif kind == "docx":
        heads = scan_docx(fp)
        lines.append("## 見出し（自動抽出）")
        lines.extend(f"- {h}" for h in heads) if heads else lines.append("(見出しスタイルなし)")
    elif kind == "csv":
        lines.append(f"ヘッダ: `{scan_csv(fp)}`")
    elif kind == "md":
        title, heads = scan_md(fp)
        if title:
            lines.append(f"タイトル: {title}")
        lines.extend(f"- {h}" for h in heads)
    return "\n".join(lines) if lines else "(自動抽出対象外の形式 — 所在のみ登録)"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True)
    ap.add_argument("--scan", required=True)
    ap.add_argument("--max", type=int, default=500)
    args = ap.parse_args()
    base, scan = Path(args.base), Path(args.scan)
    if not base.is_dir() or not scan.is_dir():
        print(f"ref-scan: base か scan ディレクトリが不在: {base} / {scan}", file=sys.stderr)
        return 1
    out_dir = base / "docs" / "refs"
    out_dir.mkdir(parents=True, exist_ok=True)
    today = datetime.date.today().isoformat()

    created = updated = unchanged = errors = 0
    seen = 0
    for dirpath, dirnames, filenames in os.walk(scan):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIR and not d.startswith(".")]
        for fn in sorted(filenames):
            if fn.startswith((".", "~$")):
                continue
            fp = Path(dirpath) / fn
            ext = fp.suffix.lower().lstrip(".")
            kind = ext if ext in ("xlsx", "docx", "csv", "md") else "other"
            seen += 1
            if seen > args.max:
                print(f"ref-scan: --max {args.max} に到達（残りは未走査）", file=sys.stderr)
                break
            st = fp.stat()
            stat_sig = f"{st.st_size}:{st.st_mtime_ns}"
            card = out_dir / card_name(fp)
            if card.exists():
                old = card.read_text(errors="replace")
                m = re.search(r"^source_stat:\s*(\S+)$", old[:2000], re.M)
                if m and m.group(1) == stat_sig:
                    unchanged += 1
                    continue
            try:
                body = build_body(fp, kind)
            except Exception as e:  # 単一ファイルの破損でスキャン全体を止めない
                body = f"(自動抽出失敗: {type(e).__name__} — 所在のみ登録)"
                errors += 1
            source = "fileserver" if str(fp).startswith("/Volumes/") else "local"
            # 要約は決定論抽出の対象外（LLM 判定層は Phase 2）。空のまま出すと検索に永遠に
            # 載らないため、必ずプレースホルダで可視化する（人間 / エージェントが後で埋める）。
            text = (
                "---\n"
                f"title: {fp.name}\n"
                f"source: {source}\n"
                f"uri: {fp}\n"
                f"fetched: {today}\n"
                f"source_stat: {stat_sig}\n"
                "generated: ref-scan\n"
                "---\n\n"
                f"# {fp.name}\n\n"
                "(要約未記入 — 検索に載らない)\n\n"
                f"{body}\n"
            )
            if card.exists():
                updated += 1
            else:
                created += 1
            card.write_text(text)
        else:
            continue
        break
    print(f"ref-scan: scanned={seen} created={created} updated={updated} unchanged={unchanged} errors={errors} -> {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
