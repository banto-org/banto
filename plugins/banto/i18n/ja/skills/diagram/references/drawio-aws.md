# draw.io で AWS 構成図を作る手順

同 skill の render-pipeline.md は draw.io 経路の最小スケルトンと SVG 化の手順（CLI がなければ `.drawio` を併納してクライアント編集に委ねる）を扱う。本ガイドはその応用として、AWS 構成図に特有の記法（アイコンセット・VPC / サブネット / AZ の入れ子・命名規則）に特化する。

## .drawio XML の基本構造（再掲なし・差分のみ）

render-pipeline.md のスケルトン（`mxfile` → `diagram` → `mxGraphModel` → `root`）をそのまま使い、AWS 図では `mxCell` の `style` 属性に AWS 専用の shape 指定を追加する。ページサイズは横長構成図が多いため `pageWidth="1169" pageHeight="827"`（A4 横）を基準にする。

## AWS アイコンセット（shape ライブラリ名）

draw.io は AWS 公式アイコンを `mxgraph.aws4` という shape ライブラリ名で内蔵する（draw.io デスクトップ / app.diagrams.net の Shapes パネルで「AWS」を検索すると出てくる「AWS / AWS4」がこれにあたる）。サービスの矩形アイコンは `shape=mxgraph.aws4.<service>` の形式で指定する。

```xml
<mxCell id="ec2_1" value="Web サーバ" style="sketch=0;outlineConnect=0;fontColor=#232F3E;gradientColor=none;fillColor=#ED7100;strokeColor=none;dashed=0;verticalLabelPosition=bottom;verticalAlign=top;align=center;html=1;fontSize=12;fontStyle=0;shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.ec2;" vertex="1" parent="1">
  <mxGeometry x="240" y="200" width="48" height="48" as="geometry"/>
</mxCell>
```

`resIcon=mxgraph.aws4.ec2` の部分をサービスごとに差し替える（`rds` / `s3` / `lambda` / `dynamodb` / `elastic_load_balancing` など）。正確なアイコン名は draw.io の Shapes パネルでサービス名を検索し、配置したアイコンを右クリック → 「スタイルの編集」で確認するのが最も確実（アイコン名はマイナーバージョンで増減するため、使う直前に実物のアイコンから style 文字列を確認する）。

## VPC / サブネット / AZ の入れ子表現

AWS 構成図は「リージョン ⊃ VPC ⊃ AZ ⊃ サブネット ⊃ リソース」の入れ子構造を、draw.io のグループコンテナ（`container=1`）の入れ子で表現する。外側から内側へ座標を親要素基準の相対値ではなく絶対座標で書くのが `mxGraphModel` の作法。

```xml
<!-- VPC コンテナ -->
<mxCell id="vpc" value="VPC: 10.0.0.0/16" style="fillColor=#F2F6E8;strokeColor=#7AA116;dashed=0;verticalAlign=top;fontSize=12;container=1;collapsible=0;shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_vpc;" vertex="1" parent="1">
  <mxGeometry x="80" y="80" width="600" height="360" as="geometry"/>
</mxCell>

<!-- AZ コンテナ（VPC 内） -->
<mxCell id="az_a" value="AZ: ap-northeast-1a" style="fillColor=#E6F2F8;strokeColor=#147EBA;dashed=1;verticalAlign=top;fontSize=11;container=1;collapsible=0;shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.availability_zone;" vertex="1" parent="vpc">
  <mxGeometry x="20" y="40" width="260" height="280" as="geometry"/>
</mxCell>

<!-- サブネット（AZ 内） -->
<mxCell id="subnet_public_a" value="Public Subnet" style="fillColor=#E6F8ED;strokeColor=#7AA116;dashed=0;verticalAlign=top;fontSize=11;container=1;collapsible=0;shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_public_subnet;" vertex="1" parent="az_a">
  <mxGeometry x="16" y="30" width="228" height="110" as="geometry"/>
</mxCell>
```

入れ子は「リージョン → VPC → AZ → サブネット」の 4 段までに抑える。5 段を超えるとラベル表示の余白がなくなり視認性が落ちるため、AZ を省略してサブネットを VPC 直下に置くなど図を単純化する。プライベートサブネットとパブリックサブネットは色を変え（`fillColor` を変更）、凡例なしでも一目で区別できるようにする。

## 命名とラベル規則

ノードのラベルは「サービス名 + 役割」の組み合わせを固定書式にする。「EC2」だけ、「サーバ」だけのような単語 1 つのラベルは禁止し、読み手が図単体で構成を理解できる情報量を持たせる。

- 良い例: 「EC2: Web サーバ（Auto Scaling）」「RDS: 注文 DB（Multi-AZ）」
- 悪い例: 「サーバ」「DB」（役割が分からない）「i-0a1b2c3d4e5f」（インスタンス ID そのまま。読み手に意味がない）

VPC / サブネットのラベルには CIDR を含める（「VPC: 10.0.0.0/16」）。IP レンジを図から読み取れると、後続のレビューで文章を読み返す手間が減る。

## 編集可能な .drawio を成果物に併納する規約

SVG 化して資料に埋め込んだ後も、`.drawio` の元ファイルを資料と同じディレクトリに残す（例 `docs/architecture/vpc-overview.drawio` + `vpc-overview.svg`）。クライアントが自分の環境で app.diagrams.net から開いて手を入れられることが、この経路を選ぶ価値そのもの。SVG だけを納品して `.drawio` を捨てると、次回の改訂が手描きからのやり直しになる。

## CLI でのエクスポート方法

draw.io デスクトップアプリ（`brew install --cask drawio`）を導入済みの環境では CLI 経由で SVG / PNG に変換できる。

```sh
drawio --export --format svg --output vpc-overview.svg vpc-overview.drawio
```

未導入の環境（現状このリポジトリの検証環境も未導入）では、render-pipeline.md の draw.io フォールバック（`.drawio` 併納 + 案内文）に従う。SVG 化が必須な場合のみ導入を提案し、ユーザー確認の上で進める。

## セルフチェック

- shape 指定が `mxgraph.aws4.*` で統一され、旧世代（`mxgraph.aws3.*`）と混在していないか
- VPC → AZ → サブネットの入れ子が 4 段以内か
- ラベルが「サービス名 + 役割」で、単語 1 つのラベルが残っていないか
- VPC / サブネットのラベルに CIDR が入っているか
- `.drawio` の元ファイルを SVG と同じ場所に併納したか
- 色がリソース種別（EC2 系 / DB 系 / ネットワーク系）で一貫しているか
