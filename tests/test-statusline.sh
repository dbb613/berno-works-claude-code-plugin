#!/usr/bin/env bash
# Tests for statusline/statusline-command.sh. Run: bash tests/test-statusline.sh
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fails=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1: $2"; fails=$((fails + 1)); }

# A repo whose own config tries to run commands when git inspects it.
repo="$tmp/evil"
git init -q "$repo"
echo a > "$repo/f"; git -C "$repo" add f; git -C "$repo" -c user.email=t@t -c user.name=t commit -qm init
echo b > "$repo/f"  # dirty, so diff has work to do
git -C "$repo" config core.fsmonitor "touch $tmp/pwned-fsmonitor; false"
git -C "$repo" config diff.external "touch $tmp/pwned-diff #"

input="{\"workspace\":{\"current_dir\":\"$repo\"},\"model\":{\"display_name\":\"Opus\"}}"

test_repo_config_cannot_run_commands() {
  out="$(printf '%s' "$input" | bash "$root/statusline/statusline-command.sh" 2>&1)"
  if [ -e "$tmp/pwned-fsmonitor" ] || [ -e "$tmp/pwned-diff" ]; then
    fail "${FUNCNAME[0]}" "repo config executed: $(ls "$tmp" | grep pwned | tr '\n' ' ')"
  else
    pass "${FUNCNAME[0]}"
  fi
}

test_still_shows_branch_and_dirty() {
  out="$(printf '%s' "$input" | bash "$root/statusline/statusline-command.sh" 2>&1)"
  [[ "$out" == *"*)"* && "$out" == *"Opus"* ]] && pass "${FUNCNAME[0]}" || fail "${FUNCNAME[0]}" "out=$out"
}

test_repo_config_cannot_run_commands
test_still_shows_branch_and_dirty
[ $fails -eq 0 ] && echo "ALL PASS" || echo "$fails FAILED"
exit $fails
