#!/usr/bin/env bash
# Installs berno-works-plugin and all of its dependencies at user scope.
# Safe to re-run: on an existing setup it also pulls the latest plugin version.
#
# Claude Code (as of 2.1.302) installs only one missing dependency per install
# operation, and only from marketplaces already added, so add them all and
# install each dependency explicitly.
set -uo pipefail

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

failed=()

# Run a claude command quietly; on failure show its output and keep going.
step() {
  local label="$1"; shift
  echo "→ $label"
  local out
  if ! out="$(claude "$@" 2>&1)"; then
    echo "$out" >&2
    failed+=("$label")
  fi
}

# A marketplace that is already added (even from another source) is fine:
# dependencies resolve by marketplace name.
for repo in "${MARKETPLACE_REPOS[@]}" "$SELF_REPO"; do
  step "marketplace $repo" plugin marketplace add "$repo"
done
step "refresh berno-works" plugin marketplace update berno-works

for plugin in "${DEPENDENCIES[@]}" berno-works-plugin@berno-works; do
  step "install $plugin" plugin install "$plugin"
done
step "update berno-works-plugin" plugin update berno-works-plugin@berno-works

if [ ${#failed[@]} -gt 0 ]; then
  echo
  echo "Finished with ${#failed[@]} failed step(s):" >&2
  printf '  - %s\n' "${failed[@]}" >&2
  exit 1
fi
echo "Done. Start a new Claude Code session, or run /reload-plugins in an open one."
