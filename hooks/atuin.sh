#!/usr/bin/env bash
# Records Bash tool calls in atuin shell history. Does nothing if atuin isn't installed.
command -v atuin >/dev/null 2>&1 || exit 0
exec atuin hook claude-code
