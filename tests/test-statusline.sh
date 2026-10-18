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
# A clean filter defined in the repo's own config, applied via .gitattributes.
echo '* filter=evil' > "$repo/.git/info/attributes"
git -C "$repo" config filter.evil.clean "touch $tmp/pwned-filter; cat"
touch -d '2000-01-01' "$repo/f"  # force git to re-read content rather than trust stat

# The same filter, hidden in a file pulled in by include.path.
inc="$tmp/inc"
git init -q "$inc"
echo a > "$inc/f"; git -C "$inc" add f; git -C "$inc" -c user.email=t@t -c user.name=t commit -qm init
echo b > "$inc/f"; touch -d '2000-01-01' "$inc/f"
echo '* filter=evil2' > "$inc/.git/info/attributes"
printf '[filter "evil2"]\n\tclean = touch %s/pwned-include; cat\n' "$tmp" > "$tmp/included.cfg"
git -C "$inc" config include.path "$tmp/included.cfg"

# An ordinary dirty repo, to check the marker still works.
plain="$tmp/plain"
git init -q "$plain"
echo a > "$plain/f"; git -C "$plain" add f; git -C "$plain" -c user.email=t@t -c user.name=t commit -qm init
echo b > "$plain/f"

input="{\"workspace\":{\"current_dir\":\"$repo\"},\"model\":{\"display_name\":\"Opus\"}}"

test_repo_config_cannot_run_commands() {
  out="$(printf '%s' "$input" | bash "$root/statusline/statusline-command.sh" 2>&1)"
  if ls "$tmp" | grep -q pwned; then
    fail "${FUNCNAME[0]}" "repo config executed: $(ls "$tmp" | grep pwned | tr '\n' ' ')"
  else
    pass "${FUNCNAME[0]}"
  fi
}

test_included_filter_cannot_run() {
  printf '{"workspace":{"current_dir":"%s"}}' "$inc" | bash "$root/statusline/statusline-command.sh" >/dev/null 2>&1
  [ ! -e "$tmp/pwned-include" ] && pass "${FUNCNAME[0]}" || fail "${FUNCNAME[0]}" "included filter executed"
}

test_still_shows_branch_and_dirty() {
  plain_input="{\"workspace\":{\"current_dir\":\"$plain\"},\"model\":{\"display_name\":\"Opus\"}}"
  out="$(printf '%s' "$plain_input" | bash "$root/statusline/statusline-command.sh" 2>&1)"
  [[ "$out" == *"*)"* && "$out" == *"Opus"* ]] && pass "${FUNCNAME[0]}" || fail "${FUNCNAME[0]}" "out=$out"
}

test_repo_config_cannot_run_commands
test_included_filter_cannot_run
test_still_shows_branch_and_dirty
[ $fails -eq 0 ] && echo "ALL PASS" || echo "$fails FAILED"
exit $fails
