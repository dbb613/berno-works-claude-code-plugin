#!/usr/bin/env bash
# Installs berno-works-plugin and all of its dependencies at user scope. Safe to re-run.
#
# Claude Code (as of 2.1.302) installs only one missing dependency per install
# operation, and only from marketplaces already added, so add them all and
# install each dependency explicitly.
set -euo pipefail

MARKETPLACE_REPOS=(
  anthropics/claude-plugins-official
  backnotprop/plannotator
  trailofbits/skills
  astral-sh/claude-code-plugins
  pydantic/skills
  max-sixty/worktrunk
)

DEPENDENCIES=(
  superpowers@claude-plugins-official
  context7@claude-plugins-official
  pyright-lsp@claude-plugins-official
  typescript-lsp@claude-plugins-official
  frontend-design@claude-plugins-official
  github@claude-plugins-official
  code-review@claude-plugins-official
  skill-creator@claude-plugins-official
  plannotator@plannotator
  modern-python@trailofbits
  astral@astral-sh
  pydantic@pydantic-skills
  ai@pydantic-skills
  worktrunk@worktrunk
)

SELF_REPO="${BERNO_WORKS_SOURCE:-dbb613/berno-works-claude-code-plugin}"

for repo in "${MARKETPLACE_REPOS[@]}" "$SELF_REPO"; do
  echo "→ marketplace $repo"
  claude plugin marketplace add "$repo" >/dev/null
done

for plugin in "${DEPENDENCIES[@]}" berno-works-plugin@berno-works; do
  echo "→ install $plugin"
  claude plugin install "$plugin" >/dev/null
done

echo "Done. Start a new Claude Code session, or run /reload-plugins in an open one."
