#!/usr/bin/env python3
"""HTML検証チェッカー ― タグ整合とJS抽出を機械検証しPASS/FAILを返す。

使い方: python3 verify-html.py <file.html>
検証: (1)主要タグの開閉一致 (2)id重複 (3)<script>内JSを/tmpに抽出（node --checkは呼び出し側で実行）
"""
import sys, re, io
from html.parser import HTMLParser

VOID = {'meta','br','hr','img','input','link','line','path','rect','circle','polygon',
        'text','tspan','marker','defs','use','ellipse'}

def main():
    path = sys.argv[1]
    s = io.open(path, encoding="utf-8").read()
    ok = True

    class P(HTMLParser):
        def __init__(self):
            super().__init__(); self.stack=[]; self.stray=[]
        def handle_starttag(self, t, a):
            if t not in VOID: self.stack.append(t)
        def handle_endtag(self, t):
            if t in VOID: return
            if t in self.stack:
                while self.stack and self.stack[-1]!=t: self.stack.pop()
                if self.stack: self.stack.pop()
            else: self.stray.append(t)
    p=P(); p.feed(s)
    if p.stack: print(f"FAIL: 未閉鎖タグ {p.stack[-8:]}"); ok=False
    if p.stray: print(f"WARN: 対応しない閉じタグ {set(p.stray)}（<p>の自動閉鎖なら許容）")

    for tag in ['section','svg','figure','table','dl','script','style']:
        o=len(re.findall(r'<%s[ >]'%tag, s)); c=len(re.findall(r'</%s>'%tag, s))
        mark = 'OK' if o==c else 'NG'
        if o!=c: ok=False
        print(f"  {tag}: open={o} close={c} {mark}")

    ids = re.findall(r'\sid="([^"]+)"', s)
    dups = {i for i in ids if ids.count(i)>1}
    if dups: print(f"FAIL: id重複 {dups}"); ok=False

    # 属性付きも含む全 <script> を連結抽出（src 付き外部参照は本 skill では禁止のため中身のみ）
    scripts = re.findall(r'<script[^>]*>(.*?)</script>', s, re.S)
    scripts = [c for c in scripts if c.strip()]
    if scripts:
        io.open('/tmp/_verify_extracted.js','w',encoding='utf-8').write('\n;\n'.join(scripts))
        print(f"  JS抽出: {len(scripts)} ブロックを連結 → /tmp/_verify_extracted.js → `node --check /tmp/_verify_extracted.js` を実行すること")

    print("PASS" if ok else "FAIL")
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
