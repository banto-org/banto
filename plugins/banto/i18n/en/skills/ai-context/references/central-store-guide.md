# Central store — deploy / sync / team operation guide (store-first)

ai-context knowledge (decisions / docs / tasks / sessions / workspaces) is consolidated into the **central store**
(default `~/ai-context-store/<project>/`). **With store-first (v5.30.0+) no setup is needed — it is written here
from the start** — the only optional part is "whether to git-sync as a team".

## Resolution order (where the hook picks the base)

1. **mapping hit**: already registered in `<store>/.mapping.json` → that project dir
2. **grandfather**: only legacy repos that have an existing `.ai-context/` actually present in the repo → keep working in-repo
   (can migrate to the store with `/ai-context migrate`)
3. **derive**: if unregistered, auto-number `<store>/<dirname of git toplevel>/` (with a `-2` suffix on collision) + auto-register

Nothing is created on the repo side (CONTRACT.md "zero footprint exceptions").

---

## Per-scenario procedures

### (a) Start using it on one personal machine — **nothing to do**

Just install the plugin and start Claude Code in the repo. The first session's scaffold auto-creates the
store root (marker `.ai-context-store` + `.mapping.json`) and the project skeleton, and subsequent
decisions / tasks land there. It is guaranteed once you've run `harness-setup.sh`.

- To change the store root location: override with `env.AI_CONTEXT_STORE_ROOT` in settings.json
- Check command: `sh "$CLAUDE_PLUGIN_ROOT/scripts/_ai-context-paths.sh" --resolve "$PWD"`

### (b) Take it to a second PC (personal multi-machine)

The actual body of the knowledge is the whole `~/ai-context-store/`. You only need to move that. **3 steps**:

1. Install banto on the new machine (`claude plugin install banto@banto-marketplace` + `harness-setup.sh`)
2. Bring the store over — either:
   - **if git-synced (solo backup of (d) done / team (c))**: `git clone <your store repo> ~/ai-context-store`
   - if not on git: `rsync -a old:~/ai-context-store/ ~/ai-context-store/`
3. Just clone each project repo anywhere and start Claude Code:
   - repo with a git remote → auto-reconnect via `.mapping-template.json` (remotes-based) or derive (same dirname)
   - **no machine-specific path registration needed** (the resolver's remote fallback, v5.21.22+)

`.mapping.json` itself is machine-local (excluded by the store's .gitignore). Even without bringing it, it is auto-regenerated.

**Operation rule for running multiple machines in parallel on git**: before starting a session, `git -C ~/ai-context-store pull --rebase`
(push is one-way automatic via PreCompact auto-sync / nightly. pull is currently manual — forgetting to pull means working on stale knowledge).

### (c) Git-sync as a team

Just make the store a private git repo. **The store must be private because it contains internal names and cross-project knowledge**.

First time (admin, only once):
```sh
cd ~/ai-context-store
git init -b main && git add -A && git commit -m "init store"
gh repo create <org>/ai-context-store --private --source . --push   # private required
```
Members (once per machine): set the org in **`~/.claude/banto-store-target.conf`**
(one line of `AI_CONTEXT_STORE_ORG="<org>"`. editing the in-plugin `config/store-target.conf` also works, but
**it reverts on every `claude plugin update`**, so the user-scope side is recommended)
`sh "$CLAUDE_PLUGIN_ROOT/scripts/ai-context-store-init.sh"`
(= clone + auto-generate `.mapping.json` from `.mapping-template.json`).

Daily sync (push is for team/other-machine sync. Everything works locally even without it):
```sh
git -C ~/ai-context-store pull --rebase
git -C ~/ai-context-store add -A && git -C ~/ai-context-store commit -m "..."
git -C ~/ai-context-store push origin main   # the store allows direct push to main via the marker (the opposite policy from code repos)
```

### (d) Backup / restore

- **The only backup target is the whole `~/ai-context-store/`** (there is no knowledge on the repo side)

**Solo git backup (recommended, only once)** — the initial store-first state is not a git repo, so init it first:

```sh
git -C ~/ai-context-store init -b main
git -C ~/ai-context-store add -A && git -C ~/ai-context-store commit -m "init store"
gh repo create <your-account>/ai-context-store --private --source ~/ai-context-store --push   # private required
```

After that, PreCompact auto-sync / nightly push takes effect (the store allows direct push to main via the marker).
If not running on git, preserve the whole directory with Time Machine / rsync, etc.

- Regenerable artifacts need no backup: `combined.txt` (the search text layer; the hook auto-regenerates it)
- Restore = same as (b) (just put the directory back and start)

---

## Migrating and removing legacy repos

The canonical migration doc (migrate / old-layout conversion / removal) is `references/setup.md`. Essentials only:
`/ai-context migrate` is a copy (the original stays); cleanup is automated by a hook (if a manual step is needed,
follow the `doctor` report; precondition: the store has been pushed).

## Daily usage (reference / save)

- The SessionStart hook injects `[AI Context - 中央 store 運用] ... ベース: <absolute path>` (the literal label the hook emits; "中央 store 運用" = central-store operation, "ベース" = base) →
  always Read/Write decisions / docs / tasks **under the injected absolute path**
- Search is `/search <query>` (targets the store's decisions/docs). Add search targets via `config.json`'s `extra_docs_dirs`
- Plugin updates / mapping changes take effect by **restarting Claude Code**

## Related

- `references/setup.md` (migrate / fallback / denylist) / `references/directory-structure.md` (read contract for external tools)
- `~/ai-context-store/README.md` (store layout)
