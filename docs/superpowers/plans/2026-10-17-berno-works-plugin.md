# berno-works-plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn this repo into a self-hosted marketplace whose one plugin
installs the owner's curated Claude Code environment: 14 dependency plugins,
4 vendored skills and a SessionStart preferences hook.

**Architecture:** The repo root is both the marketplace
(`.claude-plugin/marketplace.json`) and the plugin (`.claude-plugin/plugin.json`,
`source: "./"`). Dependencies are declared in `plugin.json`, and foreign
marketplaces are allowlisted in `marketplace.json`. A bash SessionStart hook
prints `hooks/preferences.md` plus warnings for missing CLIs.

**Tech Stack:** Claude Code plugin system, bash (POSIX-compatible enough for macOS bash 3.2), `gh`, `git`.

**Spec:** `docs/superpowers/specs/2026-10-17-berno-works-plugin-design.md`

## Global Constraints

- Plugin name `berno-works-plugin`; marketplace name `berno-works`; GitHub repo `dbb613/berno-works-claude-code-plugin` (public).
- No files written into user projects; no `CLAUDE.md` at plugin root.
- `claude plugin validate --strict .` must pass.
- No version constraints on dependencies.
- `preferences.md` ≈25 lines; hook output must stay short.
- Hook works on Linux and macOS; `${CLAUDE_PLUGIN_ROOT}` quoted.
- Vendored skills copied unchanged, each with `UPSTREAM.md` (repo, path, commit SHA, license).
- License MIT.

## Review Focus

1. Plugin path contains spaces → hook must still run (quoted root). Test in Task 3.
2. All prerequisite CLIs present → hook prints no warning lines. Test in Task 3.
3. Cross-marketplace deps on a clean config → every dependency ends up installed, not silently skipped. Checked in Task 5.
4. Vendored skill folder name ≠ frontmatter `name` → skill fails to load or gets renamed. Checked in Task 2.
5. Re-running `update-vendored.sh` with no upstream change → produces no diff. Checked in Task 2.

---

### Task 1: Git init, manifests, scaffold cleanup

**Files:**
- Create: `.gitignore` (ignore `var/`), `.claude-plugin/marketplace.json`, `LICENSE` (MIT, "Berno Works", 2026)
- Modify: `.claude-plugin/plugin.json`
- Delete: `agents/`, `skills/pr-prep/`

**Interfaces:**
- Produces: marketplace `berno-works` with one plugin `berno-works-plugin` at `source: "./"`.

- [ ] **Step 1:** `git init -b main`. Inspect `var/` (`find var`); if it holds only tooling state, add `var/` to `.gitignore`, don't delete it.
- [ ] **Step 2:** Delete `agents/` and `skills/pr-prep/`.
- [ ] **Step 3:** Write `plugin.json`: keep `name`, `version` (bump to `1.1.0`), `description`, `author`; add `"repository": "https://github.com/dbb613/berno-works-claude-code-plugin"`, `"license": "MIT"`, and `dependencies` as objects `{ "name", "marketplace" }`:
  - `claude-plugins-official`: superpowers, context7, pyright-lsp, typescript-lsp, frontend-design, github, code-review, skill-creator
  - `plannotator`: plannotator
  - `trailofbits`: modern-python
  - `astral-sh`: astral
  - `pydantic-skills`: pydantic, ai
  - `worktrunk`: worktrunk
- [ ] **Step 4:** Write `marketplace.json`: `name: "berno-works"`, `owner: { "name": "Berno Works" }`, `allowCrossMarketplaceDependenciesOn: ["claude-plugins-official","plannotator","trailofbits","astral-sh","pydantic-skills","worktrunk"]`, one plugin entry `{ "name": "berno-works-plugin", "source": "./" }`.
- [ ] **Step 5:** Run `claude plugin validate --strict .` → Expected: `Validation passed`. Also validate the marketplace file if the CLI distinguishes them.
- [ ] **Step 6:** Commit `chore: turn repo into berno-works marketplace with dependency bundle`. (Also commit the spec and this plan.)

### Task 2: Vendored skills + update script

**Files:**
- Create: `scripts/update-vendored.sh`, `scripts/vendored.tsv`
- Create (by the script): `skills/<name>/…` + `skills/<name>/UPSTREAM.md` for each row

**Interfaces:**
- Produces: `scripts/update-vendored.sh` (no args) — for each row of `vendored.tsv` (`folder<TAB>repo<TAB>path`), fetches the directory at upstream HEAD via `gh api` tarball or a shallow sparse clone into `$TMPDIR`, replaces `skills/<folder>/` with it, writes `UPSTREAM.md` (repo, path, SHA, license SPDX, date). Exits non-zero on any fetch failure without touching that folder.

`vendored.tsv` rows (all MIT, verified 2026-10-17):

| folder | repo | path |
|---|---|---|
| `fastapi` | fastapi/fastapi | `fastapi/.agents/skills/fastapi` |
| `shadcn` | shadcn-ui/ui | `skills/shadcn` |
| `vercel-react-best-practices` | vercel-labs/agent-skills | `skills/react-best-practices` |
| `tailwind-design-system` | wshobson/agents | `plugins/frontend-mobile-development/skills/tailwind-design-system` |

Folder names must equal each SKILL.md's frontmatter `name` (Vercel's is `vercel-react-best-practices`, hence the folder name). If any other upstream `name` differs from its folder, use the frontmatter name as the folder.

- [ ] **Step 1:** Write the script and TSV. `UPSTREAM.md` content must not include the date if the SHA is unchanged (so a rerun is a no-op): write the date only when the SHA changes.
- [ ] **Step 2:** Run `scripts/update-vendored.sh` → 4 folders created, each with `SKILL.md` and `UPSTREAM.md`.
- [ ] **Step 3:** Check names: `for d in skills/*/; do grep -m1 '^name:' $d/SKILL.md; done` — each equals its folder.
- [ ] **Step 4:** Run the script again, then `git status --porcelain skills/` → Expected: empty after the first commit (Review Focus 5).
- [ ] **Step 5:** `claude plugin validate --strict .` passes. Commit `feat: vendor fastapi, shadcn, vercel react and tailwind skills`.

### Task 3: SessionStart preferences hook

**Files:**
- Create: `hooks/hooks.json`, `hooks/session-start.sh` (executable), `hooks/preferences.md`
- Test: `tests/test-session-start.sh`

**Interfaces:**
- Produces: `hooks/session-start.sh` — reads `$CLAUDE_PLUGIN_ROOT` (falls back to the script's parent dir), prints `preferences.md` to stdout, then one line `berno-works: '<cmd>' not found on PATH (<purpose>)` for each missing command in: `uv`, `ruff`, `ty`, `pyright`, `plannotator`, `node`. Always exits 0.
- `hooks.json`: `SessionStart` with matcher `startup|resume|clear|compact`, command `"${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh"` (quoted).

- [ ] **Step 1: Write the failing test** `tests/test-session-start.sh` (plain bash, exits non-zero on failure):
  - `test_prints_preferences`: output contains the first heading line of `preferences.md`.
  - `test_warns_missing`: with `PATH` set to a temp dir containing symlinks to only the tools the script itself uses (e.g. `cat`, `dirname`), output contains `'uv' not found` and `'plannotator' not found`.
  - `test_no_warnings_when_present`: temp dir with stub executables for all six names (+ `cat`) → output has zero lines matching `not found` (Review Focus 2).
  - `test_root_with_spaces`: copy `hooks/` into a temp dir named `a b/hooks`, run with `CLAUDE_PLUGIN_ROOT="…/a b"` → exits 0 and prints preferences (Review Focus 1).
- [ ] **Step 2:** Run `bash tests/test-session-start.sh` → FAIL (script missing).
- [ ] **Step 3:** Write `preferences.md` (≈25 lines, content per spec §4: default stack; Python 3.15 typed modern syntax, readability; uv/ruff/ty-or-pyright/pytest; Context7 before writing against library APIs esp. SQLAlchemy 2.x, Alembic, Reveal.js; Reveal.js for decks; empty "Superpowers workflow preferences" section). Write `session-start.sh` and `hooks.json`.
- [ ] **Step 4:** Run `bash tests/test-session-start.sh` → all PASS. `claude plugin validate --strict .` passes.
- [ ] **Step 5:** Commit `feat: SessionStart hook with house preferences and prerequisite checks`.

### Task 4: README

**Files:** Create `README.md`

- [ ] **Step 1:** Write sections: What it is; Install (the two commands from spec §1, plus any extra `marketplace add` lines Task 5 proves necessary); Prerequisites (uv, ruff, ty, pyright, Plannotator CLI, Node, with one-line install hints); What's included (dependency table + vendored skills with upstream links); Customizing (edit `hooks/preferences.md`; it overrides Superpowers defaults); Updating vendored skills (`scripts/update-vendored.sh`); Optional extras (playwright, commit-commands, code-simplifier, claude-md-management, security-guidance, chrome-devtools-mcp, playground, linear); Existing setups (already-installed plugins satisfy dependencies; no migration needed).
- [ ] **Step 2:** Commit `docs: README`.

### Task 5: Clean-config install verification, then publish

- [ ] **Step 1:** In `$CLAUDE_JOB_DIR/tmp`, `export CLAUDE_CONFIG_DIR=$(mktemp -d)`; run `claude plugin marketplace add <repo path>` then `claude plugin install berno-works-plugin@berno-works`.
- [ ] **Step 2:** `claude plugin list` → Expected: `berno-works-plugin` plus all 14 dependencies installed and enabled (Review Focus 3). If foreign marketplaces had to be added manually first, record exactly which and update README Install; re-run from a fresh config dir to confirm the documented steps work.
- [ ] **Step 3:** Run the installed copy's hook directly (`CLAUDE_PLUGIN_ROOT=<installed path> <installed path>/hooks/session-start.sh`) → prints preferences.
- [ ] **Step 4:** Create the GitHub repo and push: `gh repo create dbb613/berno-works-claude-code-plugin --public --source . --push`.
- [ ] **Step 5:** Repeat Steps 1–2 with `claude plugin marketplace add dbb613/berno-works-claude-code-plugin` → same result. Fix README if anything differs; commit and push.
