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

# Dependencies — version & package-manager selection

Path-scoped to manifests / lockfiles. Two decisions live here: which **version** to pin, and which
**package manager** to run. Never hand-edit a lockfile — that belongs to `code-editing.md` (enforced
deterministically by `lint-guard.sh`).

## 1. Choosing a version — the newest that is BOTH stable AND free of known vulnerabilities

Do not blindly pin the highest version number. Supply-chain compromises (hijacked npm publishes,
malicious post-install scripts, dependency-confusion) mean the very newest release is sometimes the
*least* safe. The target is the **latest version that is both stable and free of known advisories** —
not "latest" for its own sake.

Before pinning a version:

1. **Check the latest stable.** Never reuse a number from cutoff knowledge ("React 18.2.0").
   - `npm view <pkg> version` · `npm view <pkg> dist-tags` (separate `latest` from `next` / `beta`)
   - `pip index versions <pkg>` · `gh api repos/{owner}/{repo}/releases/latest --jq .tag_name`
2. **Check that candidate for known vulnerabilities / incidents.**
   - `npm audit` · `osv-scanner` · `pip-audit` · GitHub Security Advisories · OSV.dev
   - If the latest carries an open advisory, step up to the latest **patched** version that clears it.
3. **Distrust a just-published release.** A version published hours / days ago with no adoption can be
   a compromised publish — prefer a slightly older, proven release, UNLESS the new one *is* the
   security fix.

When currency and security conflict, **security wins**: use the newest version that is maintained AND
has no open advisory. When unknown, delegate to `research-agent` (latest stable + breaking changes +
known CVEs).

### Forbidden
- ❌ Pinning cutoff-era version numbers as-is (e.g. "React 18.2.0")
- ❌ Taking "latest" without a vulnerability / advisory check
- ❌ Pinning a brand-new, zero-adoption release without a reason
- ❌ Inheriting an existing pin blindly without checking currency + advisories
- ❌ Asserting "the latest is probably fine"

### Exceptions (record why in a comment or a decision log)
- The user explicitly specifies a version ("build it with Vue 2")
- Mandatory compatibility with existing / legacy code
- A newer version is intentionally avoided for a non-security reason

## 2. Choosing the package manager — from the project, never a personal default

The **manifest** decides the ecosystem; an existing **lockfile** decides which PM within it.

1. **An existing lockfile wins** — use the PM that owns it:

   | Lockfile | PM | | Lockfile | PM |
   |---|---|---|---|---|
   | `package-lock.json` | `npm` | | `Cargo.lock` | `cargo` |
   | `yarn.lock` | `yarn` | | `Gemfile.lock` | `bundle` |
   | `pnpm-lock.yaml` | `pnpm` | | `composer.lock` | `composer` |
   | `bun.lockb` / `bun.lock` | `bun` | | `poetry.lock` / `uv.lock` / `Pipfile.lock` | `poetry` / `uv` / `pipenv` |
   | `pubspec.lock` | `flutter pub` / `dart pub` | | | |

2. **The manifest is ecosystem truth — never cross ecosystems** (no Node PM inside a Rust / Flutter /
   Go project). `package.json`→Node · `pubspec.yaml`→Flutter/Dart · `Cargo.toml`→Rust · `go.mod`→Go ·
   `Gemfile`→Ruby · `composer.json`→PHP · `pyproject.toml` / `requirements*.txt`→Python (the project's
   `uv` / `poetry` / `pip` per the lockfile).
3. **Bare manifest, no lockfile → ambiguous: ask, don't switch on the user's behalf.** Respect an
   explicit user choice. In a monorepo, decide by the manifest **closest to the working directory**.

### Forbidden
- ❌ Imposing a personal default PM (e.g. "always pnpm") on a project that already uses another
- ❌ Crossing ecosystems (a Node PM inside a Flutter / Rust project, etc.)
