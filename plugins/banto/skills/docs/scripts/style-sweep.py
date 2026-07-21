#!/usr/bin/env python3
"""表現スイープ・チェッカー ― 硬い・冗長・AIっぽい表現を検出しPASS/FAILを返す。

使い方:
  python3 style-sweep.py <対象ファイル> [--known 除外コンテキストファイル] [--mixed-ok]

--mixed-ok: 文体（です・ます / だ・である）の混在を意図して許す場合に指定する
  （引用の多い資料・場面の異なる文書の合本など。理由を報告に明記すること）。

対象: .html（style/script/svgを除いた本文）または .md/.txt。
検出パターンと言い換え先の正典は references/wording-swaps.md。
出力: パターンごとの件数・行番号・言い換え候補。検出ゼロでPASS(exit 0)、残ればFAIL(exit 1)。
除外ファイル: 1行1文字列。意図的に残す表現の「前後文脈を含む断片」を登録する（判定の記録になる）。
  例: 「規約に基づき」を残すなら行に 規約に基づき と書く。
"""
import sys, re, io

# (名前, 正規表現, 言い換え候補)
PATTERNS = [
    ("することができる",   r"することができ",             "〜できる（冗長。可能形単独で足りる）"),
    ("することが可能",     r"することが可能",             "〜できる"),
    ("されうる",           r"され[うえ]る|され得る",       "〜される可能性がある／〜されることがある"),
    ("しうる",             r"し[うえ]る(?=[。、が）\s])|し得る", "〜する可能性がある"),
    ("たりうる",           r"たり[うえ]る|たり得る",       "〜になりうる／〜となる可能性がある"),
    ("サ変+を行う",        r"[一-龥]{2}を行[ういっわ]",     "〜する（調査を行う→調査する。「処理を行う」は許容）"),
    ("サ変+を実行",        r"[一-龥]{2}を実行",           "〜する（「処理を実行」は許容）"),
    ("において",           r"におい[てた]",               "で／では（改まった文脈なら除外登録）"),
    ("に関して",           r"に関し[てた]",               "〜について"),
    ("に基づき",           r"に基づ[きい]",               "〜をもとに／〜に沿って（法令調なら除外登録）"),
    ("しかしながら",       r"しかしながら",               "しかし"),
    ("その結果として",     r"その結果として",             "その結果"),
    ("であると言える",     r"であると言え",               "「である」か「と言える」の片方だけ"),
    ("であると考えて",     r"であると考え",               "「である」か「と考えている」の片方だけ"),
    ("であろう",           r"であろう",                   "だろう／〜と推測される"),
    ("であるところの",     r"であるところの",             "削って直接係らせる"),
    ("二重表現(最初)",     r"一番最初|まず最初|まず初め",  "最初（に）"),
    ("のではないか",       r"のではない[かで]",           "〜ではないか（「の」を削る）"),
    ("空虚な強調",         r"非常に|極めて",               "原則削除し、数値・事実で置き換える"),
    ("予告・総括",         r"重要なのは|まとめると",       "予告せず中身を書く（AIっぽさの典型）"),
    ("根拠なき緩和",       r"と言えるだろう|と言えるでしょう", "言い切るか、確度表現（wording-swaps 2節）へ"),
    ("二重否定",           r"ないわけではな|なくはな",     "肯定形に直す（公用文: 二重否定は原則禁止）"),
]
ALLOW_BUILTIN = ["処理を行", "処理を実行"]  # textlint 準拠の既定許容

def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__); sys.exit(2)
    path = args[0]
    known = list(ALLOW_BUILTIN)
    if "--known" in args:
        kf = args[args.index("--known") + 1]
        known += [l.strip() for l in io.open(kf, encoding="utf-8") if l.strip()]
    s = io.open(path, encoding="utf-8").read()
    if path.lower().endswith((".html", ".htm")):
        s = re.sub(r"<style>.*?</style>|<script>.*?</script>|<svg.*?</svg>", "", s, flags=re.S)
        s = re.sub(r"<[^>]+>", "", s)
    lines = s.splitlines()

    findings = []  # (パターン名, 行番号, 前後文脈, 候補)
    for name, pat, sugg in PATTERNS:
        for i, line in enumerate(lines, 1):
            for m in re.finditer(pat, line):
                ctx = line[max(0, m.start() - 10):m.end() + 10].strip()
                # 除外は「登録断片が検出箇所そのものと重なる」場合のみ（隣接語への巻き込み防止）
                def overlaps(k):
                    st = 0
                    while (idx := line.find(k, st)) != -1:
                        if idx < m.end() and m.start() < idx + len(k):
                            return True
                        st = idx + 1
                    return False
                if any(overlaps(k) for k in known):
                    continue
                findings.append((name, i, ctx, sugg))

    # ですます/である混在の粗い検査（両方が3回以上なら指摘。--mixed-ok で許容に降格）
    mixed_ok = "--mixed-ok" in args
    desu = len(re.findall(r"(です|ます|ません|でした)。", s))
    dearu = len(re.findall(r"(である|だ)。", s))
    mixed = desu >= 3 and dearu >= 3 and not mixed_ok

    total = len(findings)
    print(f"検出 {total} 件 / 除外登録 {len(known)} 断片 / 文体: です・ます {desu} 文, だ・である {dearu} 文")
    if findings:
        print("\n検出（1 つずつ判定: 言い換える or 意図的なら除外ファイルに文脈断片を登録）:")
        byname = {}
        for name, i, ctx, sugg in findings:
            byname.setdefault((name, sugg), []).append((i, ctx))
        for (name, sugg), hits in sorted(byname.items(), key=lambda x: -len(x[1])):
            print(f"  [{name}] {len(hits)} 件 → {sugg}")
            for i, ctx in hits[:5]:
                print(f"      L{i}: …{ctx}…")
    if mixed:
        print("\n[文体混在] です・ます と だ・である が併存しています。文書単位で統一してください（引用は除外可）")
    if findings or mixed:
        print("\nFAIL: 表現スイープに残件があります")
        sys.exit(1)
    print("PASS: 検出ゼロ")
    sys.exit(0)

if __name__ == "__main__":
    main()
