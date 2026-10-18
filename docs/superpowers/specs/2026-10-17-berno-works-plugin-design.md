# berno-works-plugin: design

Date: 2026-10-17
Owner: Berno Works (GitHub: `dbb613`)

## Intent

One install that gives the owner the same Claude Code environment in every
project they open. The goal is that Claude writes the best, most readable
modern Python (3.15, fully typed) and front-end code on the owner's stack,
using a consistent workflow (Superpowers, Plannotator, Context7).

The owner prefers **well-adopted existing skills and plugins over writing
their own**. This plugin is therefore mostly a curated *bundle*: a manifest
of dependencies, a few skills vendored from upstream, and a small hook.
Original content stays minimal.

## Goals

- Installing `berno-works-plugin` once (user scope) brings in every
  dependency below automatically, on any machine.
- Claude defaults to the owner's stack and tools without being reminded:
  Python 3.15 + full type annotations, uv/ruff/ty, FastAPI, Pydantic v2,
  PydanticAI, SQLAlchemy 2.x + Postgres, React + TypeScript, Tailwind,
  shadcn/ui, Reveal.js for decks.
- Claude looks up current library docs through Context7 rather than relying
  on memory, especially where no good skill exists (SQLAlchemy, Alembic,
  Reveal.js).
- The Superpowers workflow can be tuned later by editing one text file in
  this plugin, without forking Superpowers.

## Non-goals

- **No files written into projects.** No project `CLAUDE.md`,
  `.claude/settings.json`, `pyproject.toml`, ruff config, and so on. The
  setup follows the user, not the repo. Collaborators and CI are out of
  scope.
- No hand-written Python/FastAPI/React style skills. Use upstream ones.
- No forking or replacing Superpowers skills.

## Anti-goals (failure even if it "works")

- Silently missing dependencies. For example, a cross-marketplace dependency
  that is skipped and makes the plugin fail to load.
- A plugin that competes with Superpowers for triggering, such as a
  same-named `brainstorming` skill.
- Large always-on context. The SessionStart text must stay short.

## Components

### 1. Repo is also its own marketplace

Add `.claude-plugin/marketplace.json` at the repo root, listing this plugin
with `"source": "./"`. Install flow on a new machine:

```
claude plugin marketplace add dbb613/berno-works-claude-code-plugin
claude plugin install berno-works-plugin@berno-works
```

The marketplace must set `allowCrossMarketplaceDependenciesOn` to every
foreign marketplace below. Without that, Claude Code skips cross-marketplace
dependencies declared in `plugin.json`, and the plugin then fails to load.
Docs: https://code.claude.com/docs/en/plugins/dependencies

Open for the builder: whether the user must first `marketplace add` each
foreign marketplace, or whether the allowlist plus dependency install
resolves them. Verify this on a clean config (for example
`CLAUDE_CONFIG_DIR=$(mktemp -d)`). If adding them manually is required,
document the extra `marketplace add` lines in the README install section.

### 2. Dependencies (`plugin.json`)

| Plugin | Marketplace (name → repo) | Purpose |
|---|---|---|
| `superpowers` | `claude-plugins-official` → anthropics/claude-plugins-official | Workflow (brainstorm → plan → TDD → review) |
| `context7` | `claude-plugins-official` | Up-to-date library docs (MCP) |
| `pyright-lsp` | `claude-plugins-official` | Live type diagnostics after edits |
| `plannotator` | `plannotator` → backnotprop/plannotator | Plan/code review UI |
| `modern-python` | `trailofbits` → trailofbits/skills | uv, ruff, ty, pyproject, PEP 723/735 |
| `astral` | `astral-sh` → astral-sh/claude-code-plugins | Official uv/ruff/ty skills |
| `pydantic` | `pydantic-skills` → pydantic/skills | Pydantic v2 patterns |
| `ai` | `pydantic-skills` → pydantic/skills | PydanticAI agents |
| `typescript-lsp` | `claude-plugins-official` | Live TS/React type diagnostics |
| `frontend-design` | `claude-plugins-official` | Front-end UI quality |
| `github` | `claude-plugins-official` | GitHub MCP |
| `code-review` | `claude-plugins-official` | `/code-review` |
| `skill-creator` | `claude-plugins-official` | Authoring skills |
| `worktrunk` | `worktrunk` → max-sixty/worktrunk | Git worktree workflow |

The owner's other user-scope plugins (playwright, commit-commands,
code-simplifier, claude-md-management, security-guidance,
chrome-devtools-mcp, playground, linear) are deliberately left out. The
README lists them as optional manual installs.

Every entry uses the object form `{ "name", "marketplace" }`.

**No version constraints.** Constraints resolve against
`<plugin>--v<version>` git tags. Superpowers tags releases as `v7.0.0`, so a
constraint would fail to install. The official marketplace already pins
Superpowers to a commit SHA, so it only moves when that marketplace updates.

Builder's call (made in design): use the Pydantic team's own marketplace for
both `pydantic` and `ai`, not the official marketplace's `pydantic-ai` entry,
to avoid a duplicate. Keep both `pyright-lsp` and `astral`. Trail of Bits
prefers `ty`, but `pyright-lsp` is the only option that gives live LSP
diagnostics today. The hook text names `ty` as the CLI checker in projects
that use it.

### 3. Vendored skills (`skills/`)

These upstream skills are not published as plugins, so copy them into
`skills/<name>/` unchanged. Each folder gets an `UPSTREAM.md` recording the
source repo, path, commit SHA and license.

| Skill | Source | Notes |
|---|---|---|
| `fastapi` | fastapi/fastapi (official) | Find its SKILL.md path in the repo |
| `shadcn` | shadcn-ui/ui (official) | |
| `react-best-practices` | vercel-labs/agent-skills | Leans toward Next.js; keep as is |
| `tailwind-design-system` | wshobson/agents | Community-made, 69K installs |

Before vendoring, check each license allows redistribution. If one doesn't,
drop it and list it in the README as an optional manual
`npx skills add …` instead.

Add `scripts/update-vendored.sh`, which re-fetches each skill at upstream
HEAD, updates `UPSTREAM.md`, and leaves the diff for review. It runs
manually, not on a schedule.

### 4. SessionStart hook (`hooks/hooks.json` + `hooks/preferences.md`)

A SessionStart hook prints `hooks/preferences.md` as `additionalContext`,
the same mechanism Superpowers uses to load itself. This file is the single
place to customize behavior, including the Superpowers workflow.
Superpowers states that user instructions take precedence over its skills.

Initial content, kept to about 25 lines, is the builder's to write. It
covers:
- The default stack, listed above.
- Python: target 3.15, annotate everything, prefer modern syntax
  (`X | None`, built-in generics, `type` aliases, PEP 695), and favor
  readability.
- Tooling: uv for everything (`uv add`, `uv run`), ruff for lint and format,
  ty or pyright for types, pytest.
- Use Context7 for library docs before writing against an API, especially
  SQLAlchemy 2.x, Alembic and Reveal.js.
- Reveal.js is the default for slide decks.
- A placeholder section, "Superpowers workflow preferences", empty for now.

Use the exec form or a quoted `${CLAUDE_PLUGIN_ROOT}` path. The hook must
work on Linux and macOS.

### 5. Clean up the existing scaffold

- `plugin.json`: keep name, version and author. Replace `dependencies`
  with the table above, and add `repository` and `license` (MIT, the
  builder's call).
- Remove the empty `agents/` and `skills/pr-prep/` directories (the owner
  confirmed `pr-prep` is leftover). Leave `var/` alone; it was created
  by tooling, so check what it is before touching it.
- Add `README.md` with what the plugin does, install commands, the
  dependency list, and how to edit preferences.

## Constraints

- No `CLAUDE.md` at the plugin root (Claude Code ignores it; validate warns).
- Must pass `claude plugin validate --strict` for both the plugin and the
  marketplace.
- Repo is not yet a git repo. Initialize it and create the GitHub repo
  `dbb613/berno-works-claude-code-plugin` (public, so `marketplace add`
  works without auth). The owner approved creating the public repo and
  pushing once local verification passes.

## Calls made in design (owner to check)

- **Prerequisites are not installed by the plugin.** The `pyright` binary,
  the Plannotator CLI, Node, and uv/ruff/ty are listed in a README
  "Prerequisites" section. The SessionStart hook prints one short warning
  line for each one missing from PATH and otherwise stays silent.
- **Verification uses a local-path marketplace**
  (`marketplace add /path/to/repo`) in a throwaway `CLAUDE_CONFIG_DIR`. The
  check is non-interactive: run `claude plugin list`, and run the hook
  script directly to confirm its output. A GitHub-sourced re-check happens
  only after the owner approves the push.
- **Vendor, don't depend on, wshobson/agents and vercel-labs.** Even where
  they are plugin marketplaces, their plugins bundle many unrelated skills,
  which conflicts with the anti-goals. Copy the single skill instead.
- **Existing standalone installs on this machine are left alone.** Claude
  Code treats an already-enabled plugin as satisfying a dependency. The
  README notes that an existing setup needs no migration.

## Done when

- `claude plugin validate --strict` passes.
- In a clean config directory, the two install commands result in every
  dependency installed and enabled, the vendored skills listed, and the
  preferences text visible at session start.
- README install steps match what actually worked.

## Left to the builder

The exact wording of `preferences.md`, the README prose, the update-script
details, and the order of tasks.
