---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.mjs"
  - "**/*.cjs"
  - "**/*.py"
  - "**/*.pyx"
  - "**/*.rs"
  - "**/*.go"
  - "**/*.rb"
  - "**/*.java"
  - "**/*.kt"
  - "**/*.swift"
  - "**/*.c"
  - "**/*.h"
  - "**/*.cpp"
  - "**/*.hpp"
  - "**/*.cc"
  - "**/*.cxx"
  - "**/*.m"
  - "**/*.mm"
  - "**/*.sh"
  - "**/*.bash"
  - "**/*.zsh"
  - "**/*.php"
  - "**/*.lua"
  - "**/*.dart"
  - "**/*.scala"
  - "**/*.clj"
  - "**/*.ex"
  - "**/*.exs"
  - "**/*.elm"
  - "**/*.fs"
  - "**/*.ml"
  - "**/*.hs"
  - "**/*.vue"
  - "**/*.svelte"
  - "**/package-lock.json"
  - "**/yarn.lock"
  - "**/pnpm-lock.yaml"
  - "**/bun.lock"
  - "**/bun.lockb"
  - "**/Cargo.lock"
  - "**/Gemfile.lock"
  - "**/poetry.lock"
  - "**/uv.lock"
  - "**/composer.lock"
  - "**/go.sum"
---

# コード編集ルール

ソースコードを編集する際に適用する具体的なルール。AI の応答や設計判断に関する一般原則は `quality.md` を参照。

## ソースコード本体

- 変更していないコードにコメント / docstring / 型注釈を追加しない
- 単発使用のヘルパー関数を作らない。3 行の重複は、早すぎる抽象化に勝る
- 起こりえないシナリオへのエラーハンドリングを追加しない
- 仮説上の将来要件に向けて設計しない

## 依存関係 / lockfile

- lockfile（package-lock.json / yarn.lock / pnpm-lock.yaml / bun.lock / bun.lockb / Cargo.lock / Gemfile.lock / poetry.lock / uv.lock / composer.lock / go.sum 等）を直接編集しない。パッケージマネージャ経由で更新する（`lint-guard.sh` により決定論的に強制）
