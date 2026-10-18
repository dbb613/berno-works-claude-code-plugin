#!/usr/bin/env bash
# SessionStart hook: refreshes the status line script, prints the house preferences,
# then one warning line per missing CLI.
# Stdout from a SessionStart hook is added to Claude's context.

root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Keep the status line in step with the plugin version. It lives at a stable path
# because user settings can't reference ${CLAUDE_PLUGIN_ROOT}.
config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
statusline="$config_dir/berno-works-statusline.sh"
if ! cmp -s "$root/statusline/statusline-command.sh" "$statusline" 2>/dev/null; then
  mkdir -p "$config_dir" && cp "$root/statusline/statusline-command.sh" "$statusline" 2>/dev/null
fi

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
jq the status line
atuin shell history of Bash tool calls
TOOLS

if [ -n "$missing" ]; then
  printf '\n## Missing tools (tell the user once if relevant)%s\n' "$missing"
fi
exit 0
