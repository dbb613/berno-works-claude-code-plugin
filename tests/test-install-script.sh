#!/usr/bin/env bash
# Tests scripts/install.sh against a stub `claude` that logs calls and fails on demand.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fails=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1: $2"; fails=$((fails + 1)); }

mkdir -p "$tmp/bin"
cat > "$tmp/bin/claude" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$CLAUDE_STUB_LOG"
case " $* " in *" $CLAUDE_STUB_FAIL "*) echo "stub failure for $*"; exit 1 ;; esac
exit 0
STUB
chmod +x "$tmp/bin/claude"

run() {  # run <failing-arg>
  : > "$tmp/log"
  out="$(PATH="$tmp/bin:$PATH" CLAUDE_STUB_LOG="$tmp/log" CLAUDE_STUB_FAIL="$1" bash "$root/scripts/install.sh" 2>&1)"; rc=$?
}

test_continues_after_marketplace_add_fails() {
  run "max-sixty/worktrunk"
  grep -q "plugin install berno-works-plugin@berno-works" "$tmp/log" && [ $rc -ne 0 ] && [[ "$out" == *"max-sixty/worktrunk"* ]] \
    && pass "${FUNCNAME[0]}" || fail "${FUNCNAME[0]}" "rc=$rc log=$(tr '\n' ';' < "$tmp/log")"
}

test_continues_after_install_fails() {
  run "superpowers@claude-plugins-official"
  grep -q "plugin install worktrunk@worktrunk" "$tmp/log" && [ $rc -ne 0 ] \
    && pass "${FUNCNAME[0]}" || fail "${FUNCNAME[0]}" "rc=$rc"
}

test_updates_existing_install() {
  run "no-such-arg"
  grep -q "plugin marketplace update berno-works" "$tmp/log" && grep -q "plugin update berno-works-plugin@berno-works" "$tmp/log" && [ $rc -eq 0 ] \
    && pass "${FUNCNAME[0]}" || fail "${FUNCNAME[0]}" "rc=$rc log=$(tr '\n' ';' < "$tmp/log")"
}

test_continues_after_marketplace_add_fails
test_continues_after_install_fails
test_updates_existing_install
[ $fails -eq 0 ] && echo "ALL PASS" || echo "$fails FAILED"
exit $fails
