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

# Code editing rules

Concrete rules applied when editing source code. For general principles on AI responses and design decisions, see `quality.md`.

## Source code itself

- Don't add comments/docstrings/type annotations to code you didn't change
- Don't create single-use helper functions. 3 duplicated lines beat a premature abstraction
- Don't add error handling for impossible scenarios
- Don't design for hypothetical future requirements

## Dependencies / lockfiles

- Never edit lockfiles (package-lock.json / yarn.lock / pnpm-lock.yaml / bun.lock / bun.lockb / Cargo.lock / Gemfile.lock / poetry.lock / uv.lock / composer.lock / go.sum, etc.) directly. Update them through the package manager (enforced deterministically by `lint-guard.sh`)
