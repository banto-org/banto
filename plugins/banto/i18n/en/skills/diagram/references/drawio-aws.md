# Building an AWS architecture diagram in draw.io

The existing html-doc skill's diagrams.md covers the minimal draw.io skeleton and the SVG-export
pipeline (falling back to shipping the `.drawio` for client-side editing when no CLI is available).
This guide builds on that, specializing in notation specific to AWS architecture diagrams — the
icon set, nested VPC/subnet/AZ structure, and naming conventions.

## Basic .drawio XML structure (not restated — differences only)

Use diagrams.md's skeleton (`mxfile` → `diagram` → `mxGraphModel` → `root`) as-is. For AWS diagrams,
add AWS-specific shape declarations to each `mxCell`'s `style` attribute. Since AWS diagrams tend to
be wide, use `pageWidth="1169" pageHeight="827"` (landscape A4) as the baseline page size.

## The AWS icon set (shape library name)

draw.io bundles the official AWS icons under the shape library name `mxgraph.aws4` (this is what
appears as "AWS / AWS4" when you search "AWS" in the Shapes panel of draw.io desktop / app.diagrams.net).
Service rectangle icons take the form `shape=mxgraph.aws4.<service>`.

```xml
<mxCell id="ec2_1" value="Web server" style="sketch=0;outlineConnect=0;fontColor=#232F3E;gradientColor=none;fillColor=#ED7100;strokeColor=none;dashed=0;verticalLabelPosition=bottom;verticalAlign=top;align=center;html=1;fontSize=12;fontStyle=0;shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.ec2;" vertex="1" parent="1">
  <mxGeometry x="240" y="200" width="48" height="48" as="geometry"/>
</mxCell>
```

Swap the `resIcon=mxgraph.aws4.ec2` portion per service (`rds` / `s3` / `lambda` / `dynamodb` /
`elastic_load_balancing`, etc.). The most reliable way to get the exact icon name is to search the
service name in draw.io's Shapes panel, place the icon, right-click it, and check "Edit Style" —
icon names shift across minor versions, so confirm the style string against the real icon right
before you use it.

## Expressing nested VPC / subnet / AZ structure

An AWS architecture diagram expresses the "Region ⊃ VPC ⊃ AZ ⊃ Subnet ⊃ Resource" nesting through
nested draw.io group containers (`container=1`). It's `mxGraphModel` convention to write coordinates
from outer to inner as absolute values, not relative to the parent.

```xml
<!-- VPC container -->
<mxCell id="vpc" value="VPC: 10.0.0.0/16" style="fillColor=#F2F6E8;strokeColor=#7AA116;dashed=0;verticalAlign=top;fontSize=12;container=1;collapsible=0;shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_vpc;" vertex="1" parent="1">
  <mxGeometry x="80" y="80" width="600" height="360" as="geometry"/>
</mxCell>

<!-- AZ container (inside VPC) -->
<mxCell id="az_a" value="AZ: ap-northeast-1a" style="fillColor=#E6F2F8;strokeColor=#147EBA;dashed=1;verticalAlign=top;fontSize=11;container=1;collapsible=0;shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.availability_zone;" vertex="1" parent="vpc">
  <mxGeometry x="20" y="40" width="260" height="280" as="geometry"/>
</mxCell>

<!-- Subnet (inside AZ) -->
<mxCell id="subnet_public_a" value="Public Subnet" style="fillColor=#E6F8ED;strokeColor=#7AA116;dashed=0;verticalAlign=top;fontSize=11;container=1;collapsible=0;shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_public_subnet;" vertex="1" parent="az_a">
  <mxGeometry x="16" y="30" width="228" height="110" as="geometry"/>
</mxCell>
```

Cap the nesting at 4 levels: Region → VPC → AZ → Subnet. Beyond 5 levels there's no room left for
label text and readability drops — simplify instead, e.g. drop the AZ level and place the subnet
directly under the VPC. Give private and public subnets different colors (vary `fillColor`) so
they're distinguishable at a glance even without a legend.

## Naming and label conventions

Fix node labels to a "service name + role" format. A single-word label like "EC2" or "Server" is
forbidden — give the reader enough information to understand the architecture from the diagram alone.

- Good: "EC2: Web server (Auto Scaling)", "RDS: Order DB (Multi-AZ)"
- Bad: "Server", "DB" (role unclear), "i-0a1b2c3d4e5f" (a raw instance ID, meaningless to the reader)

Include the CIDR in VPC/subnet labels ("VPC: 10.0.0.0/16"). Being able to read the IP range off the
diagram saves the reviewer from cross-referencing prose later.

## Convention: ship the editable .drawio alongside the deliverable

Even after exporting to SVG and embedding it in the document, keep the original `.drawio` file in
the same directory as the document (e.g. `docs/architecture/vpc-overview.drawio` +
`vpc-overview.svg`). The client being able to open it in their own environment via
app.diagrams.net and edit it is the entire value of choosing this path. Shipping only the SVG and
discarding the `.drawio` means the next revision starts from a hand-redraw.

## Exporting via CLI

With the draw.io desktop app installed (`brew install --cask drawio`), you can convert to SVG/PNG via the CLI.

```sh
drawio --export --format svg --output vpc-overview.svg vpc-overview.drawio
```

In an environment without it installed (as is currently the case in this repo's verification
environment too), follow the html-doc skill's `render-diagram.sh` draw.io fallback (ship the
`.drawio` plus guidance text). Only propose installing it when SVG output is actually required, and
proceed with the user's confirmation.

## Self-check

- Are shape declarations unified on `mxgraph.aws4.*`, with no mix of the older `mxgraph.aws3.*`?
- Is the VPC → AZ → Subnet nesting within 4 levels?
- Do labels follow "service name + role," with no single-word labels left?
- Do VPC/subnet labels include the CIDR?
- Is the original `.drawio` shipped alongside the SVG in the same location?
- Is color consistent by resource category (EC2-family / DB-family / network-family)?
