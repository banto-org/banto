---
paths:
  - "**/package.json"
  - "**/package-lock.json"
  - "**/yarn.lock"
  - "**/pnpm-lock.yaml"
  - "**/bun.lock"
  - "**/bun.lockb"
  - "**/pubspec.yaml"
  - "**/pubspec.lock"
  - "**/Cargo.toml"
  - "**/Cargo.lock"
  - "**/go.mod"
  - "**/go.sum"
  - "**/Gemfile"
  - "**/Gemfile.lock"
  - "**/composer.json"
  - "**/composer.lock"
  - "**/pyproject.toml"
  - "**/requirements*.txt"
  - "**/poetry.lock"
  - "**/uv.lock"
  - "**/Pipfile"
  - "**/Pipfile.lock"
  - "**/.tool-versions"
  - "**/.nvmrc"
  - "**/.python-version"
---

# 依存関係 — バージョンとパッケージマネージャの選定

マニフェスト / lockfile にパス限定。ここで扱う判断は 2 つ：どの**バージョン**を固定するか、どの
**パッケージマネージャ**を実行するか。lockfile は手で編集せず、必ずパッケージマネージャ経由で
更新する（`lint-guard.sh` により決定論的に強制）。

## 1. バージョンの選定 — 安定かつ既知の脆弱性がない最新版

最も高いバージョン番号を盲目的に固定しない。サプライチェーン侵害（npm publish の乗っ取り、
悪意ある post-install スクリプト、dependency-confusion）により、最新リリースが時に*最も*
安全でないことがある。目標は**安定かつ既知のアドバイザリがない最新バージョン**であり、
「latest」そのものが目的ではない。

バージョンを固定する前に：

1. **最新の安定版を確認する。** カットオフ時点の知識のバージョン番号（「React 18.2.0」等）をそのまま再利用しない。
   - `npm view <pkg> version` · `npm view <pkg> dist-tags`（`latest` と `next` / `beta` を区別する）
   - `pip index versions <pkg>` · `gh api repos/{owner}/{repo}/releases/latest --jq .tag_name`
2. **その候補に既知の脆弱性 / インシデントがないか確認する。**
   - `npm audit` · `osv-scanner` · `pip-audit` · GitHub Security Advisories · OSV.dev
   - 最新版に未解決のアドバイザリがある場合、それを解消する最新の**パッチ済み**バージョンまで上げる。
3. **公開されたばかりのリリースを信用しない。** 数時間 / 数日前に公開され採用実績のないバージョンは
   侵害された publish の可能性がある — 新版がまさにそのセキュリティ修正である場合を除き、
   やや古く実績のあるリリースを優先する。

新しさとセキュリティが衝突する場合、**セキュリティを優先する**：メンテナンスされていて
かつ未解決のアドバイザリがない最新バージョンを使う。不明な場合は `research-agent` に委譲する
（最新安定版 + breaking changes + 既知の CVE）。

### 禁止
- ❌ カットオフ時点のバージョン番号をそのまま固定する（例：「React 18.2.0」）
- ❌ 脆弱性 / アドバイザリの確認なしに「latest」を採用する
- ❌ 理由なく採用実績ゼロの新リリースを固定する
- ❌ 新しさとアドバイザリを確認せず既存の固定を盲目的に継承する
- ❌ 「最新なら恐らく大丈夫」と断定する

### 例外（理由をコメントか decision log に記録する）
- ユーザーが明示的にバージョンを指定した場合（「Vue 2 で作って」等）
- 既存 / レガシーコードとの互換性が必須の場合
- セキュリティ以外の理由で意図的に新しいバージョンを避ける場合

## 2. パッケージマネージャの選定 — プロジェクトから決める、個人の既定値は使わない

**マニフェスト**がエコシステムを決め、既存の**lockfile**がそのエコシステム内でどの PM を使うかを決める。

1. **既存の lockfile が優先** — それを所有する PM を使う：

   | Lockfile | PM | | Lockfile | PM |
   |---|---|---|---|---|
   | `package-lock.json` | `npm` | | `Cargo.lock` | `cargo` |
   | `yarn.lock` | `yarn` | | `Gemfile.lock` | `bundle` |
   | `pnpm-lock.yaml` | `pnpm` | | `composer.lock` | `composer` |
   | `bun.lockb` / `bun.lock` | `bun` | | `poetry.lock` / `uv.lock` / `Pipfile.lock` | `poetry` / `uv` / `pipenv` |
   | `pubspec.lock` | `flutter pub` / `dart pub` | | | |

2. **マニフェストがエコシステムの真実 — エコシステムを跨がない**（Rust / Flutter /
   Go プロジェクトの中に Node の PM を持ち込まない）。`package.json`→Node · `pubspec.yaml`→Flutter/Dart ·
   `Cargo.toml`→Rust · `go.mod`→Go · `Gemfile`→Ruby · `composer.json`→PHP ·
   `pyproject.toml` / `requirements*.txt`→Python（lockfile に応じてそのプロジェクトの
   `uv` / `poetry` / `pip`）。
3. **マニフェストのみで lockfile がない場合 → 曖昧：確認する、ユーザーに代わって勝手に切り替えない。**
   ユーザーの明示的な選択を尊重する。monorepo では作業ディレクトリに**最も近い**マニフェストで判断する。

### 禁止
- ❌ 既に別の PM を使っているプロジェクトに個人の既定 PM（例：「常に pnpm」）を押し付ける
- ❌ エコシステムを跨ぐ（Flutter / Rust プロジェクトの中に Node の PM を使う等）
