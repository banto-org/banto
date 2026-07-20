#!/usr/bin/env python3
"""用語スイープ・チェッカー ― 未注釈の専門語候補を検出しPASS/FAILを返す。

使い方:
  python3 term-sweep.py <対象ファイル> [--known 除外語ファイル]

対象: .html（ツールチップ/.tip・用語集<dt>を注釈と見なす）または .md/.txt（「語（説明」形式の括弧定義を注釈と見なす）。
出力: 未注釈候補の一覧と件数。候補ゼロ（または全て除外済み）でPASS(exit 0)、残ればFAIL(exit 1)。
除外語ファイル: 1行1語。読者が確実に知っている語を判定済みとして登録する（判定の記録になる）。
"""
import sys, re, io, unicodedata

def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__); sys.exit(2)
    path = args[0]
    known = set()
    if "--known" in args:
        kf = args[args.index("--known")+1]
        known = {l.strip() for l in io.open(kf, encoding="utf-8") if l.strip()}
    s = io.open(path, encoding="utf-8").read()
    is_html = path.lower().endswith((".html", ".htm"))

    # 注釈済み語の収集
    annotated = set()
    if is_html:
        # ツールチップ: <span class="t" ...>語<span class="tip">
        for m in re.finditer(r'class="t"[^>]*>\s*([^<]{1,40})<span class="tip"', s):
            annotated.add(m.group(1).strip())
        # 用語集: <dt>語<span class="en">…</span></dt> または <dt>語</dt>
        for m in re.finditer(r'<dt>([^<]{1,40})', s):
            annotated.add(m.group(1).strip())
        body = re.sub(r'<style>.*?</style>|<script>.*?</script>|<span class="tip">.*?</span>', '', s, flags=re.S)
        body = re.sub(r'<[^>]+>', ' ', body)
    else:
        body = s
    # 括弧内定義「語（…」「語 (…」を注釈と見なす（md/txt・HTML共通で追加収集）
    for m in re.finditer(r'([ァ-ヴー]{3,}|[A-Za-z][A-Za-z0-9./+-]{1,29})（', body):
        annotated.add(m.group(1))

    # 候補抽出: カタカナ3文字以上 / 英単語・略語2文字以上
    cands = {}
    for m in re.finditer(r'[ァ-ヴー]{3,}', body):
        cands[m.group(0)] = cands.get(m.group(0), 0) + 1
    for m in re.finditer(r'\b[A-Za-z][A-Za-z0-9./+-]{1,29}\b', body):
        w = m.group(0)
        if re.fullmatch(r'\d+|[a-z]{1,2}', w):  # 数字・極短小文字は除外
            continue
        cands[w] = cands.get(w, 0) + 1

    def norm(t): return unicodedata.normalize("NFKC", t).lower()
    ann_n = {norm(a) for a in annotated}
    known_n = {norm(k) for k in known}

    misses = []
    for w, c in sorted(cands.items(), key=lambda x: -x[1]):
        n = norm(w)
        if n in known_n:  continue
        if any(n in a or a in n for a in ann_n if len(a) >= 2):  continue
        misses.append((w, c))

    print(f"候補 {len(cands)} 語 / 注釈済み検出 {len(annotated)} 語 / 除外登録 {len(known)} 語")
    if misses:
        print(f"\n未注釈候補 {len(misses)} 語（頻度順）――各語を「読者が説明なしで分かるか」判定し、")
        print("  分からない→初出に注釈を追加 / 分かる→除外語ファイルに登録:")
        for w, c in misses[:60]:
            print(f"  {c:3d}× {w}")
        print("\nFAIL: 未注釈候補が残っています")
        sys.exit(1)
    print("PASS: 未注釈候補ゼロ")
    sys.exit(0)

if __name__ == "__main__":
    main()
