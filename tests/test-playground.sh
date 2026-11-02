#!/usr/bin/env bash
# Tests for skills/playground/scripts/pg.py. Run: bash tests/test-playground.sh
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
scripts="$root/skills/playground/scripts"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fails=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1: $2"; fails=$((fails + 1)); }
pg() { python3 "$scripts/pg.py" "$@"; }
gitc() { git -c user.email=t@t -c user.name=t "$@"; }
mkrepo() {
  git init -q -b main "$1"
  echo x > "$1/.keep"; git -C "$1" add .keep; gitc -C "$1" commit -qm init
}
# mkpg <dir>: fresh initialized playgrounds repo
mkpg() { mkrepo "$1" && (cd "$1" && pg init >/dev/null); }
jget() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2], {}, {'d': d}))" "$1" "$2"; }
# jset <file> <python statement using d>
jset() { python3 -c "import json,sys; p=sys.argv[1]; d=json.load(open(p)); exec(sys.argv[2]); open(p,'w').write(json.dumps(d, indent=2)+'\n')" "$1" "$2"; }

# ---------- Task 1: skeleton and init ----------
test_init_creates_files() {
  local r="$tmp/init1"; mkrepo "$r"
  (cd "$r" && pg init >/dev/null) || { fail init_creates_files "init exited non-zero"; return; }
  for f in .playgrounds README.md INDEX.md .gitignore; do
    [ -f "$r/$f" ] || { fail init_creates_files "missing $f"; return; }
  done
  [ "$(cat "$r/.playgrounds")" = "1" ] || { fail init_creates_files ".playgrounds content"; return; }
  grep -q '^node_modules/$' "$r/.gitignore" && grep -q '^\.venv/$' "$r/.gitignore" \
    || { fail init_creates_files ".gitignore entries"; return; }
  pass init_creates_files
}

test_init_idempotent() {
  local r="$tmp/init2"; mkpg "$r"
  echo custom > "$r/README.md"
  (cd "$r" && pg init >/dev/null) || { fail init_idempotent "second init failed"; return; }
  [ "$(cat "$r/README.md")" = "custom" ] && pass init_idempotent || fail init_idempotent "README overwritten"
}

test_requires_marker() {
  local r="$tmp/nomark"; mkrepo "$r"
  local err; err="$(cd "$r" && pg index 2>&1 >/dev/null)"; local rc=$?
  [ $rc -eq 1 ] && [[ "$err" == *"pg: not a playgrounds repo"* ]] && pass requires_marker || fail requires_marker "rc=$rc err=$err"
}

test_not_git() {
  local d="$tmp/plain"; mkdir -p "$d"
  local err; err="$(cd "$d" && GIT_CEILING_DIRECTORIES="$tmp" pg init 2>&1 >/dev/null)"; local rc=$?
  [ $rc -eq 1 ] && [[ "$err" == *"pg: not inside a git repository"* ]] && pass not_git || fail not_git "rc=$rc err=$err"
}

test_subdir_uses_root() {
  local r="$tmp/sub"; mkpg "$r"; mkdir -p "$r/sub"
  (cd "$r/sub" && pg init >/dev/null)
  [ ! -e "$r/sub/.playgrounds" ] && pass subdir_uses_root || fail subdir_uses_root "wrote into subdir"
}

test_init_creates_files
test_init_idempotent
test_requires_marker
test_not_git
test_subdir_uses_root

# ---------- Task 2: validate ----------
# fixture <repo> <slug>: write a valid active playground.json at pg/<slug>/
fixture() {
  mkdir -p "$1/pg/$2"
  cat > "$1/pg/$2/playground.json" <<EOF
{
  "slug": "$2",
  "tech": "httpx",
  "version": null,
  "kind": "python",
  "use_case": "async http client",
  "mode": "guided",
  "durability": "throwaway",
  "status": "active",
  "created": "2026-11-02",
  "concluded": null,
  "questions": [
    {"id": "Q1", "text": "Does it stream?", "answer": null, "confidence": null, "experiment": null}
  ],
  "rubric": {"dx": null, "docs": null, "performance": null, "maturity": null,
             "ecosystem": null, "ops_cost": null, "license": null},
  "verdict": null,
  "verdict_draft": false,
  "compared_with": []
}
EOF
}
V="$tmp/val"; mkpg "$V"
fx="$V/pg/2026-11-02-fx/playground.json"
# expect_invalid <name> <python mutation> <substring expected in output>
expect_invalid() {
  fixture "$V" 2026-11-02-fx; jset "$fx" "$2"
  local out; out="$(cd "$V" && pg validate 2026-11-02-fx 2>&1)"; local rc=$?
  [ $rc -eq 1 ] && [[ "$out" == *"$3"* ]] && pass "$1" || fail "$1" "rc=$rc out=$out"
}

test_validate_ok() {
  fixture "$V" 2026-11-02-fx
  local out; out="$(cd "$V" && pg validate 2026-11-02-fx 2>&1)"; local rc=$?
  [ $rc -eq 0 ] && [ "$out" = "ok 2026-11-02-fx" ] && pass validate_ok || fail validate_ok "rc=$rc out=$out"
}
test_validate_ok
expect_invalid validate_bad_enum "d['verdict']='maybe'" verdict
expect_invalid validate_missing_field "del d['rubric']" rubric
expect_invalid validate_bool_score "d['rubric']['dx']=True" dx
expect_invalid validate_concluded_needs_verdict "d['status']='concluded'; d['concluded']='2026-11-03'" verdict
expect_invalid validate_unknown_key "d['verdikt']='adopt'" verdikt
expect_invalid validate_bad_question "d['questions'][0]['answer']='sure'" answer

test_validate_slug_mismatch() {
  fixture "$V" 2026-11-02-other; jset "$V/pg/2026-11-02-other/playground.json" "d['slug']='2026-11-02-fx'"
  local out; out="$(cd "$V" && pg validate 2026-11-02-other 2>&1)"; local rc=$?
  rm -rf "$V/pg/2026-11-02-other"
  [ $rc -eq 1 ] && [[ "$out" == *slug* ]] && pass validate_slug_mismatch || fail validate_slug_mismatch "rc=$rc out=$out"
}
test_validate_slug_mismatch

[ $fails -eq 0 ] && echo "PASS playground" || echo "$fails failure(s)"
exit $fails
