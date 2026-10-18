# berno-works-plugin

One install that gives you the same Claude Code environment in every project:
the Superpowers workflow, modern typed Python on a FastAPI / Pydantic /
SQLAlchemy stack, React + Tailwind + shadcn on the front end, and current
library docs through Context7.

It lives at user scope and follows you around. It never writes files into
your projects.

## Install

```sh
claude plugin marketplace add dbb613/berno-works-claude-code-plugin
claude plugin install berno-works-plugin@berno-works
```

Installing the plugin installs every dependency below. Start a new session
(or run `/reload-plugins`) afterwards.

## Prerequisites

The plugin doesn't install command-line tools. At session start it prints a
one-line warning for each of these that's missing from `PATH`:

| Tool | Used by | Install |
|---|---|---|
| `uv` | Python projects | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| `ruff` | lint and format | `uv tool install ruff` |
| `ty` | type checking | `uv tool install ty` |
| `pyright` | `pyright-lsp` live diagnostics | `npm i -g pyright` or `uv tool install pyright` |
| `plannotator` | Plannotator plan review | see [backnotprop/plannotator](https://github.com/backnotprop/plannotator) |
| `node` | `npx`, `typescript-lsp` | https://nodejs.org |

## What's included

**Plugin dependencies**

| Plugin | Marketplace | For |
|---|---|---|
| superpowers | claude-plugins-official | brainstorm → plan → TDD → review workflow |
| context7 | claude-plugins-official | up-to-date library docs |
| pyright-lsp | claude-plugins-official | live Python type diagnostics |
| typescript-lsp | claude-plugins-official | live TypeScript diagnostics |
| frontend-design | claude-plugins-official | front-end UI quality |
| github | claude-plugins-official | GitHub MCP |
| code-review | claude-plugins-official | `/code-review` |
| skill-creator | claude-plugins-official | writing skills |
| plannotator | [plannotator](https://github.com/backnotprop/plannotator) | plan and code review UI |
| modern-python | [trailofbits](https://github.com/trailofbits/skills) | uv, ruff, ty, pyproject conventions |
| astral | [astral-sh](https://github.com/astral-sh/claude-code-plugins) | official uv / ruff / ty skills |
| pydantic, ai | [pydantic-skills](https://github.com/pydantic/skills) | Pydantic v2 and PydanticAI |
| worktrunk | [worktrunk](https://github.com/max-sixty/worktrunk) | git worktree workflow |

**Vendored skills** (copied unchanged; each folder's `UPSTREAM.md` records
the source commit)

| Skill | Source |
|---|---|
| `fastapi` | [fastapi/fastapi](https://github.com/fastapi/fastapi) |
| `shadcn` | [shadcn-ui/ui](https://github.com/shadcn-ui/ui) |
| `vercel-react-best-practices` | [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) |
| `tailwind-design-system` | [wshobson/agents](https://github.com/wshobson/agents) |

## Customizing

Edit [`hooks/preferences.md`](hooks/preferences.md). It's loaded at the
start of every session as your standing instructions, and it takes
precedence over skill defaults, including Superpowers. Add workflow tweaks
under "Superpowers workflow preferences" instead of forking Superpowers.

## Updating vendored skills

```sh
scripts/update-vendored.sh   # re-fetches changed skills at upstream HEAD
git diff skills/             # review before committing
bash tests/test-vendored.sh
```

Sources are listed in `scripts/vendored.tsv`.

## Already have some of these installed?

No migration needed. A plugin you've already installed and enabled
satisfies the dependency as it is.

## Optional extras (not bundled)

Install these yourself if you want them: `playwright`, `commit-commands`,
`code-simplifier`, `claude-md-management`, `security-guidance`,
`chrome-devtools-mcp`, `playground`, `linear` (all in
`claude-plugins-official`).

## Development

```sh
claude plugin validate --strict .                          # marketplace
claude plugin validate --strict .claude-plugin/plugin.json # plugin
bash tests/test-session-start.sh
bash tests/test-vendored.sh
```
