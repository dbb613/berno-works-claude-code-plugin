#!/usr/bin/env bash
# Tests for hooks/session-start.sh. Run: bash tests/test-session-start.sh
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/hooks/session-start.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fails=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1: $2"; fails=$((fails + 1)); }

# A PATH containing only the tools the hook itself needs, plus any stubs passed as args.
make_path() {
  local dir="$tmp/bin-$1"; shift
  mkdir -p "$dir"
  for tool in bash cat dirname; do ln -sf "$(command -v "$tool")" "$dir/$tool"; done
  for stub in "$@"; do printf '#!/bin/sh\n' > "$dir/$stub"; chmod +x "$dir/$stub"; done
  echo "$dir"
}

first_line="$(head -1 "$root/hooks/preferences.md" 2>/dev/null)"

test_prints_preferences() {
  out="$(CLAUDE_PLUGIN_ROOT="$root" bash "$hook" 2>&1)"
  [ -n "$first_line" ] && [[ "$out" == *"$first_line"* ]] && pass "${FUNCNAME[0]}" || fail "${FUNCNAME[0]}" "preferences heading not in output"
}

test_warns_missing() {
  p="$(make_path none)"
  out="$(PATH="$p" CLAUDE_PLUGIN_ROOT="$root" "$p/bash" "$hook" 2>&1)"
  [[ "$out" == *"'uv' not found"* && "$out" == *"'plannotator' not found"* ]] && pass "${FUNCNAME[0]}" || fail "${FUNCNAME[0]}" "expected missing-tool warnings, got: $out"
}

test_no_warnings_when_present() {
  p="$(make_path all uv ruff ty pyright plannotator node)"
  out="$(PATH="$p" CLAUDE_PLUGIN_ROOT="$root" "$p/bash" "$hook" 2>&1)"
  [ -n "$first_line" ] && [[ "$out" == *"$first_line"* && "$out" != *"not found"* ]] && pass "${FUNCNAME[0]}" || fail "${FUNCNAME[0]}" "unexpected warning in: $out"
}

test_root_with_spaces() {
  spaced="$tmp/a b"; mkdir -p "$spaced"; cp -R "$root/hooks" "$spaced/"
  out="$(CLAUDE_PLUGIN_ROOT="$spaced" bash "$spaced/hooks/session-start.sh" 2>&1)"; rc=$?
  [ $rc -eq 0 ] && [ -n "$first_line" ] && [[ "$out" == *"$first_line"* ]] && pass "${FUNCNAME[0]}" || fail "${FUNCNAME[0]}" "rc=$rc out=$out"
}

test_falls_back_without_plugin_root() {
  out="$(env -u CLAUDE_PLUGIN_ROOT bash "$hook" 2>&1)"; rc=$?
  [ $rc -eq 0 ] && [ -n "$first_line" ] && [[ "$out" == *"$first_line"* ]] && pass "${FUNCNAME[0]}" || fail "${FUNCNAME[0]}" "rc=$rc"
}

test_prints_preferences
test_warns_missing
test_no_warnings_when_present
test_root_with_spaces
test_falls_back_without_plugin_root
[ $fails -eq 0 ] && echo "ALL PASS" || echo "$fails FAILED"
exit $fails
