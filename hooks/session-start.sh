#!/usr/bin/env bash
# SessionStart hook: prints the house preferences, then one warning line per missing CLI.
# Stdout from a SessionStart hook is added to Claude's context.

root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

cat "$root/hooks/preferences.md"

missing=""
while read -r cmd purpose; do
  command -v "$cmd" >/dev/null 2>&1 || missing="$missing
berno-works: '$cmd' not found on PATH ($purpose)"
done <<'TOOLS'
uv Python projects and dependencies
ruff Python lint and format
ty Python type checking
pyright-langserver pyright-lsp diagnostics
typescript-language-server typescript-lsp diagnostics
plannotator Plannotator plan review
node npx and the TypeScript language server
TOOLS

if [ -n "$missing" ]; then
  printf '\n## Missing tools (tell the user once if relevant)%s\n' "$missing"
fi
exit 0
