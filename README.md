# berno-works-plugin

One install that gives you the same Claude Code environment in every project:
the Superpowers workflow, modern typed Python on a FastAPI / Pydantic /
SQLAlchemy stack, React + Tailwind + shadcn on the front end, and current
library docs through Context7.

It lives at user scope and follows you around. It never writes files into
your projects.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/dbb613/berno-works-claude-code-plugin/main/scripts/install.sh | bash
```

Then start a new session, or run `/reload-plugins` in an open one. The
script is safe to re-run.

Why a script and not just `claude plugin install`? Claude Code (checked on
2.1.302) only installs a dependency from a marketplace you've already added,
and it installs just **one** missing dependency per install operation. The
script adds the six source marketplaces and installs each dependency
explicitly. To do it by hand, run `claude plugin marketplace add` for each
repo in `MARKETPLACE_REPOS` in [`scripts/install.sh`](scripts/install.sh),
then `claude plugin install` for each entry in `DEPENDENCIES`, then:

```sh
claude plugin marketplace add dbb613/berno-works-claude-code-plugin
claude plugin install berno-works-plugin@berno-works
```

## Prerequisites

The plugin doesn't install command-line tools. At session start it prints a
one-line warning for each of these that's missing from `PATH`:

| Tool | Used by | Install |
|---|---|---|
| `uv` | Python projects | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| `ruff` | lint and format | `uv tool install ruff` |
| `ty` | type checking | `uv tool install ty` |
| `pyright-langserver` | `pyright-lsp` live diagnostics | `npm i -g pyright` or `uv tool install pyright` |
| `typescript-language-server` | `typescript-lsp` live diagnostics | `npm i -g typescript-language-server typescript` |
| `plannotator` | Plannotator plan review | see [backnotprop/plannotator](https://github.com/backnotprop/plannotator) |
| `node` | `npx`, the TypeScript language server | https://nodejs.org |
| `jq` | the status line | your package manager |
| `atuin` | shell history of Bash tool calls (optional) | https://atuin.sh |

`install.sh` also needs `python3` to merge user settings.

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
| `find-skills` | [vercel-labs/skills](https://github.com/vercel-labs/skills) |
| `plannotator`, `plannotator-annotate`, `-last`, `-review`, `-compound`, `-setup-goal`, `-visual-explainer` | [backnotprop/plannotator](https://github.com/backnotprop/plannotator) (Apache-2.0) |

**Personal environment**

- **Status line** (`statusline/statusline-command.sh`): copied to
  `~/.claude/berno-works-statusline.sh` at every session start, so it
  updates with the plugin.
- **Atuin hooks**: Bash tool calls are recorded in atuin history
  (`hooks/atuin.sh`; does nothing if atuin isn't installed).
- **User settings** written by `install.sh` (other keys are kept): status
  line, `tui: fullscreen`, `agentPushNotifEnabled`, and auto-update on for
  every marketplace above.
- **Not set for you:** `skipDangerousModePermissionPrompt`. It turns off a
  safety prompt, so set it yourself in `~/.claude/settings.json` if you want it.

## Customizing

Edit [`hooks/preferences.md`](hooks/preferences.md) **in this repo** (not
the installed copy under `~/.claude/plugins/cache`, which is replaced on
update). It's loaded at the start of every session as your standing
instructions, and it takes precedence over skill defaults, including
Superpowers. Add workflow tweaks under "Superpowers workflow preferences"
instead of forking Superpowers.

## Releasing a change

Commit and push. That's it for most changes.

`plugin.json` deliberately has no `version`, so every commit is a new
version, and `install.sh` turns on auto-update for the marketplace. Each
machine picks up the push in its next interactive session (within about ten
minutes of your first message; run `/reload-plugins` to apply it right away,
otherwise it applies at the next launch). One install covers every project
on the machine.

Re-run the install one-liner on each machine when you **add a dependency**
or **change the user settings** in `install.sh`. Auto-update doesn't do
those.

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
claude plugin validate .                          # marketplace
claude plugin validate .claude-plugin/plugin.json # plugin (warns: no version, on purpose)
bash tests/test-session-start.sh
bash tests/test-statusline.sh        # repo git config cannot run commands
bash tests/test-vendored.sh
bash tests/test-install-lists.sh     # install.sh matches the manifests
bash tests/test-install-script.sh    # install.sh keeps going and updates
bash tests/test-vendored-commits.sh  # network: vendored commits are current
```
