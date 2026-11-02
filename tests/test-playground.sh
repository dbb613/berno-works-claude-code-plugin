#!/usr/bin/env bash
# Tests for skills/playground/scripts/pg.py. Run: bash tests/test-playground.sh
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
scripts="$root/skills/playground/scripts"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
# Hermetic git: ignore the caller's global/system config.
: > "$tmp/gitconfig"; export GIT_CONFIG_GLOBAL="$tmp/gitconfig" GIT_CONFIG_NOSYSTEM=1
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

# ---------- Task 3: new ----------
N="$tmp/new"; mkpg "$N"
newpg() { (cd "$N" && pg new --mode guided --durability throwaway --date 2026-11-02 "$@"); }

test_new_python() {
  local slug; slug="$(newpg --tech httpx --use-case "async client" --kind python --question "Q a" --question "Q b")" \
    || { fail new_python "exit $?"; return; }
  [ "$slug" = "2026-11-02-httpx" ] || { fail new_python "slug=$slug"; return; }
  local d="$N/pg/$slug"
  for f in pyproject.toml FINDINGS.md README.md experiments/.gitkeep playground.json; do
    [ -f "$d/$f" ] || { fail new_python "missing $f"; return; }
  done
  (cd "$N" && pg validate "$slug" >/dev/null) || { fail new_python "does not validate"; return; }
  [ "$(jget "$d/playground.json" "[q['id'] for q in d['questions']]")" = "['Q1', 'Q2']" ] || { fail new_python "question ids"; return; }
  grep -q '^### Q2: Q b$' "$d/FINDINGS.md" || { fail new_python "FINDINGS question heading"; return; }
  grep -q 'pg-2026-11-02-httpx' "$d/pyproject.toml" || { fail new_python "pyproject name"; return; }
  ! grep -q '{{' "$d/FINDINGS.md" "$d/README.md" "$d/pyproject.toml" || { fail new_python "unrendered placeholder"; return; }
  pass new_python
}

test_new_each_kind() {
  local k slug
  for k in ts infra bare; do
    slug="$(newpg --tech "kind $k" --use-case u --kind "$k")" || { fail new_each_kind "$k exit"; return; }
    (cd "$N" && pg validate "$slug" >/dev/null) || { fail new_each_kind "$k does not validate"; return; }
  done
  python3 -m json.tool "$N/pg/2026-11-02-kind-ts/package.json" >/dev/null || { fail new_each_kind "package.json invalid"; return; }
  [ -x "$N/pg/2026-11-02-kind-infra/run.sh" ] || { fail new_each_kind "run.sh not executable"; return; }
  pass new_each_kind
}

test_slugify_cases() {
  local out; out="$(python3 -c "
import sys; sys.path.insert(0, sys.argv[1]); import pg
for t in ['Next.js 15', 'C++', '@tanstack/query', 'Ünïcode', 'C#', '  --Hello  World--  ', 'x'*60]:
    print(pg.slugify(t))" "$scripts")"
  local want; want="$(printf '%s\n' next-js-15 cplusplus tanstack-query unicode csharp hello-world "$(printf 'x%.0s' {1..40})")"
  [ "$out" = "$want" ] && pass slugify_cases || fail slugify_cases "got: $(echo $out)"
}

test_slug_empty_errors() {
  local err; err="$(newpg --tech '+++' --name '!!!' --use-case u --kind bare 2>&1 >/dev/null)"; local rc=$?
  [ $rc -eq 1 ] && [[ "$err" == *"pass --name"* ]] && pass slug_empty_errors || fail slug_empty_errors "rc=$rc err=$err"
}

test_new_duplicate() {
  newpg --tech dup --use-case u --kind bare >/dev/null
  local err; err="$(newpg --tech dup --use-case u --kind bare 2>&1 >/dev/null)"; local rc=$?
  [ $rc -eq 1 ] && [[ "$err" == *"already exists"* ]] && pass new_duplicate || fail new_duplicate "rc=$rc err=$err"
}

test_new_bad_kind() {
  local err; err="$(newpg --tech k --use-case u --kind rust 2>&1 >/dev/null)"; local rc=$?
  [ $rc -eq 1 ] && [[ "$err" == *"unknown kind 'rust'"* ]] && pass new_bad_kind || fail new_bad_kind "rc=$rc err=$err"
}

test_use_case_special_chars() {
  local uc; uc=$'say "hi" | then\nbye {{slug}}'
  local slug; slug="$(newpg --tech special --use-case "$uc" --kind ts)" || { fail use_case_special_chars "exit"; return; }
  python3 -m json.tool "$N/pg/$slug/package.json" >/dev/null || { fail use_case_special_chars "package.json invalid"; return; }
  local got; got="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['use_case'] == sys.argv[2])" "$N/pg/$slug/playground.json" "$uc")"
  [ "$got" = "True" ] && pass use_case_special_chars || fail use_case_special_chars "use_case did not round-trip"
}

test_templates_no_freetext_in_code() {
  local hits; hits="$(grep -rlE '\{\{(tech|use_case|questions)\}\}' "$root/skills/playground/templates" | grep -v '\.md$')"
  [ -z "$hits" ] && pass templates_no_freetext_in_code || fail templates_no_freetext_in_code "$hits"
}

test_new_python
test_new_each_kind
test_slugify_cases
test_slug_empty_errors
test_new_duplicate
test_new_bad_kind
test_use_case_special_chars
test_templates_no_freetext_in_code

# ---------- Task 4: index and findings-files ----------
I="$tmp/idx"; mkpg "$I"
newin() { (cd "$I" && pg new --mode guided --durability throwaway --kind bare "$@"); }
newin --tech drizzle --use-case orm --date 2026-10-01 >/dev/null
newin --tech kysely --use-case orm --date 2026-10-05 >/dev/null
newin --tech nats --use-case queue --date 2026-10-02 >/dev/null
jset "$I/pg/2026-10-01-drizzle/playground.json" \
  "d.update(status='concluded', concluded='2026-10-03', verdict='adopt'); d['rubric']['dx']=4"
row_of() { grep "^| \[$1\]" "$I/INDEX.md"; }

test_index_groups() {
  (cd "$I" && pg index >/dev/null) || { fail index_groups "exit"; return; }
  local f="$I/INDEX.md"
  [ "$(head -1 "$f")" = "<!-- generated by pg.py index; do not edit -->" ] || { fail index_groups "header"; return; }
  local orm queue kys dri
  orm="$(grep -n '^## orm$' "$f" | cut -d: -f1)"; queue="$(grep -n '^## queue$' "$f" | cut -d: -f1)"
  kys="$(grep -n '2026-10-05-kysely' "$f" | head -1 | cut -d: -f1)"; dri="$(grep -n '2026-10-01-drizzle' "$f" | head -1 | cut -d: -f1)"
  [ -n "$orm" ] && [ -n "$queue" ] && [ "$orm" -lt "$queue" ] || { fail index_groups "section order"; return; }
  [ "$kys" -lt "$dri" ] || { fail index_groups "newest first"; return; }
  local r; r="$(row_of 2026-10-01-drizzle)"
  [[ "$r" == *"| adopt |"* && "$r" == *"| 4 |"* ]] || { fail index_groups "row: $r"; return; }
  [[ "$r" == *"(pg/2026-10-01-drizzle/FINDINGS.md)"* ]] || { fail index_groups "link: $r"; return; }
  pass index_groups
}

test_index_draft_marker() {
  jset "$I/pg/2026-10-05-kysely/playground.json" "d.update(verdict='trial', verdict_draft=True)"
  (cd "$I" && pg index >/dev/null)
  [[ "$(row_of 2026-10-05-kysely)" == *"| trial (draft) |"* ]] && pass index_draft_marker || fail index_draft_marker "$(row_of 2026-10-05-kysely)"
}

test_index_escapes() {
  newin --tech esc --use-case $'a|b\nc' --date 2026-10-09 >/dev/null
  (cd "$I" && pg index >/dev/null)
  grep -qxF '## a\|b c' "$I/INDEX.md" || { fail index_escapes "heading"; return; }
  local bad; bad="$(grep '^|' "$I/INDEX.md" | python3 -c "
import re,sys
print(sum(1 for l in sys.stdin if len(re.findall(r'(?<!\\\\)\|', l)) != 14))")"
  [ "$bad" = "0" ] && pass index_escapes || fail index_escapes "$bad rows with wrong cell count"
}

test_index_skips_invalid() {
  newin --tech broken --use-case orm --date 2026-10-10 >/dev/null
  echo '{' > "$I/pg/2026-10-10-broken/playground.json"
  local err; err="$(cd "$I" && pg index 2>&1 >/dev/null)"; local rc=$?
  rm -rf "$I/pg/2026-10-10-broken"
  [ $rc -eq 0 ] && [[ "$err" == *"pg: warning: skipping 2026-10-10-broken"* ]] && grep -q 2026-10-02-nats "$I/INDEX.md" \
    && ! grep -q 2026-10-10-broken "$I/INDEX.md" && pass index_skips_invalid || fail index_skips_invalid "rc=$rc err=$err"
}

test_index_empty() {
  local r="$tmp/idx-empty"; mkpg "$r"; rm "$r/INDEX.md"
  (cd "$r" && pg index >/dev/null)
  grep -q '^_No playgrounds yet._$' "$r/INDEX.md" && pass index_empty || fail index_empty "$(cat "$r/INDEX.md")"
}

test_findings_files() {
  local d="$I/pg/2026-10-02-nats"; mkdir -p "$d/experiments/01-a" "$d/experiments/02-b"
  touch "$d/experiments/01-a/RESULT.md" "$d/experiments/01-a/main.py" "$d/experiments/02-b/RESULT.md"
  local out; out="$(cd "$I" && pg findings-files 2026-10-02-nats)"
  local want; want="$(printf '%s\n' pg/2026-10-02-nats/playground.json pg/2026-10-02-nats/FINDINGS.md pg/2026-10-02-nats/README.md \
    pg/2026-10-02-nats/experiments/01-a/RESULT.md pg/2026-10-02-nats/experiments/02-b/RESULT.md)"
  [ "$out" = "$want" ] && pass findings_files || fail findings_files "got: $out"
}

test_findings_files_unknown() {
  local err; err="$(cd "$I" && pg findings-files nope 2>&1 >/dev/null)"; local rc=$?
  [ $rc -eq 1 ] && [[ "$err" == *"no playground nope"* ]] && pass findings_files_unknown || fail findings_files_unknown "rc=$rc"
}

test_index_groups
test_index_draft_marker
test_index_escapes
test_index_skips_invalid
test_index_empty
test_findings_files
test_findings_files_unknown

# ---------- Task 5: clean ----------
CR="$tmp/remote.git"; C="$tmp/clone"
git init -q --bare -b main "$CR"
git clone -q "$CR" "$C" 2>/dev/null
(cd "$C" && pg init >/dev/null && git add -A && gitc commit -qm init && git push -q origin main)
# branch_pg <branch> <tech> [git env...]: playground committed on its own branch, pushed
branch_pg() {
  local br="$1" tech="$2"; shift 2
  (cd "$C" && git switch -q -c "$br" main \
    && pg new --tech "$tech" --use-case u --kind bare --mode guided --durability throwaway --date 2026-10-01 >/dev/null \
    && git add -A && env "$@" git -c user.email=t@t -c user.name=t commit -qm "$br" \
    && git push -q origin "$br" && git switch -q main)
}
branch_pg pg/2026-10-01-harv harv
branch_pg pg/2026-10-01-old old GIT_COMMITTER_DATE=2020-01-01T00:00:00
branch_pg pg/2026-10-01-fresh fresh
# Harvest "harv": its concluded findings land on main, plus a -findings branch.
(cd "$C" && git checkout -q pg/2026-10-01-harv -- pg/2026-10-01-harv/playground.json \
  && jset pg/2026-10-01-harv/playground.json "d.update(status='concluded', concluded='2026-10-02', verdict='hold')" \
  && git add -A && gitc commit -qm harvest && git push -q origin main \
  && git push -q origin main:pg/2026-10-01-harv-findings && git fetch -q origin)
CLEAN_OUT="$(cd "$C" && pg clean 2>&1)"; CLEAN_RC=$?

test_clean_harvested() {
  [ $CLEAN_RC -eq 0 ] && grep -qxP 'harvested\tpg/2026-10-01-harv' <<<"$CLEAN_OUT" \
    && pass clean_harvested || fail clean_harvested "rc=$CLEAN_RC out=$CLEAN_OUT"
}
test_clean_findings_branch() {
  grep -qxP 'harvested\tpg/2026-10-01-harv-findings' <<<"$CLEAN_OUT" \
    && pass clean_findings_branch || fail clean_findings_branch "out=$CLEAN_OUT"
}
test_clean_stale() {
  grep -qP '^stale\tpg/2026-10-01-old\t[0-9]+$' <<<"$CLEAN_OUT" && pass clean_stale || fail clean_stale "out=$CLEAN_OUT"
}
test_clean_fresh_active_ignored() {
  ! grep -q 'fresh' <<<"$CLEAN_OUT" && pass clean_fresh_active_ignored || fail clean_fresh_active_ignored "out=$CLEAN_OUT"
}
test_clean_order() {
  [ "$(cut -f1 <<<"$CLEAN_OUT" | uniq | tr '\n' ' ')" = "harvested stale " ] && pass clean_order || fail clean_order "out=$CLEAN_OUT"
}
test_clean_no_origin() {
  local err; err="$(cd "$N" && pg clean 2>&1 >/dev/null)"; local rc=$?
  [ $rc -eq 1 ] && [[ "$err" == *"no 'origin' remote"* ]] && pass clean_no_origin || fail clean_no_origin "rc=$rc err=$err"
}
test_clean_missing_base() {
  local err; err="$(cd "$C" && pg clean --base origin/nope 2>&1 >/dev/null)"; local rc=$?
  [ $rc -eq 1 ] && [[ "$err" == *"base ref 'origin/nope' not found"* ]] && pass clean_missing_base || fail clean_missing_base "rc=$rc err=$err"
}

test_clean_harvested
test_clean_findings_branch
test_clean_stale
test_clean_fresh_active_ignored
test_clean_order
test_clean_no_origin
test_clean_missing_base

[ $fails -eq 0 ] && echo "PASS playground" || echo "$fails failure(s)"
exit $fails
