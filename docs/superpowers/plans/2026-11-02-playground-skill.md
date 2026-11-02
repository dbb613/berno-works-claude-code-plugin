# Playground Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `playground` skill to this plugin. It scaffolds, runs, indexes and retires technical spikes in a dedicated playgrounds repo.

**Architecture:** `skills/playground/scripts/pg.py` is a stdlib-only Python CLI that does every deterministic operation (init, new, validate, index, findings-files, clean) against the playgrounds repo in the current directory. `SKILL.md` and its `references/` hold the judgment work: the interview, research, experiments, scoring and git/PR flow. Each command calls `pg.py` for the mechanical steps.

**Tech Stack:** Python ≥ 3.9 standard library, bash tests in the existing `tests/*.sh` style, git.

**Spec:** `docs/superpowers/specs/2026-11-02-playground-skill-design.md`

## Global Constraints

- `pg.py` uses only the Python standard library and runs on Python 3.9 (macOS system python). Put `from __future__ import annotations` at the top. No `match` statements and no 3.10+ APIs.
- Invocation: `python3 <skill-dir>/scripts/pg.py <command> [options]`. It operates on the git repo containing the current directory (`git rev-parse --show-toplevel`). There is no `--repo` flag.
- Every command except `init` requires a `.playgrounds` file at the repo root.
- Errors: exit code 1, with one line on stderr starting `pg: `. Normal output goes to stdout.
- Playground directory: `pg/<yyyy-mm-dd>-<slug-base>/`. Branch names: `pg/<slug>` for code and `pg/<slug>-findings` for a throwaway's findings PR.
- `playground.json` fields, enums and the rubric keys are exactly as in the spec's *Data formats* section.
- Rubric: `dx, docs, performance, maturity, ecosystem, ops_cost` take an int 1–5 or null, and `license` is `ok|caution|blocker|null`. Verdicts are `adopt|trial|hold|reject|null`.
- Template kinds: `python`, `ts`, `infra`, `bare`.
- Staleness threshold: 30 days.
- Tests live in `tests/test-playground.sh`. They follow the `pass`/`fail` helper pattern in `tests/test-statusline.sh`, use only temp dirs, and need no network.
- `claude plugin validate --strict .` must still pass.

## Review Focus

1. **Awkward tech names** (`Next.js 15`, `C++`, `@tanstack/query`, `Ünïcode`) must give a valid, non-empty slug. A name with no letters or digits (`+++`) must give a clear error suggesting `--name`. Tests in Task 3.
2. **A use case containing `"`, `|` or a newline** must not break `package.json`/`pyproject.toml`, nor the `INDEX.md` table. Templates only interpolate free text into `.md` files. Tests in Tasks 3 and 4.
3. **One malformed `playground.json`** must not stop `index`. That playground is skipped with a `pg: warning:` line naming it, and the rest are indexed. Test in Task 4.
4. **Running from a subdirectory** of the playgrounds repo must use the repo root, not cwd. Test in Task 1.
5. **`clean` with no `origin` remote or no `origin/main`** must give a clear error, not a traceback. Test in Task 5.

---

### Task 1: `pg.py` skeleton, repo detection, `init`

**Files:**
- Create: `skills/playground/scripts/pg.py`
- Create: `skills/playground/templates/repo/README.md`, `skills/playground/templates/repo/gitignore`
- Create: `tests/test-playground.sh`

**Interfaces:**
- Produces (module-level in `pg.py`, used by every later task):
  - `SKILL_DIR: Path`, the parent of `scripts/`
  - `class PgError(Exception)`: `main()` catches it, prints `pg: <msg>` to stderr and exits 1
  - `repo_root() -> Path`. Raises `PgError("not inside a git repository")`.
  - `require_playgrounds(root: Path) -> None`. Raises `PgError("not a playgrounds repo (no .playgrounds); run /playground init")`.
  - `main(argv: list[str] | None = None) -> int`, an argparse subcommand dispatcher. Later tasks add subparsers.
- Test helpers in `tests/test-playground.sh`: `pg() { python3 "$root/skills/playground/scripts/pg.py" "$@"; }`, `mkrepo <dir>` (git init plus an initial commit with `-c user.email=t@t -c user.name=t`), `pass`, `fail`.

- [ ] **Step 1: Write failing tests**
  - `test_init_creates_files`: in a fresh repo, `pg init` exits 0. `.playgrounds` (content `1`), `README.md`, `INDEX.md` and `.gitignore` exist. `.gitignore` contains `node_modules/` and `.venv/`.
  - `test_init_idempotent`: write `custom` into `README.md`, run `pg init` again. It exits 0 and `README.md` still reads `custom`.
  - `test_requires_marker`: in a repo without `.playgrounds`, `pg index` exits 1 and stderr contains `pg: not a playgrounds repo`.
  - `test_not_git`: in a plain temp dir, `pg init` exits 1 and stderr contains `pg: not inside a git repository`.
  - `test_subdir_uses_root`: after `pg init`, `mkdir sub && cd sub && pg init` creates no `sub/.playgrounds`.

- [ ] **Step 2: Run `bash tests/test-playground.sh`.** Expected: FAIL lines because `pg.py` doesn't exist yet.

- [ ] **Step 3: Implement.** `init` copies `templates/repo/README.md` to `README.md` and `templates/repo/gitignore` to `.gitignore`, writes `.playgrounds` and an empty `INDEX.md`. Never overwrite an existing file. Print one `created <path>` line per file it writes. Until Task 4 exists, write `INDEX.md` as the empty-index text from Task 4: header comment plus `_No playgrounds yet._`. In Task 4, replace that with a call to `render_index([])`.
  - `README.md` (repo template): what the repo is, the `/playground` commands with one line each, and the manual "graduate to its own repo" steps (`git subtree split --prefix pg/<slug>`, then push to a new repo).
  - `gitignore`: `node_modules/ .venv/ __pycache__/ .pytest_cache/ dist/ .DS_Store .env`.

- [ ] **Step 4: Run `bash tests/test-playground.sh`.** Expected: every line PASS, exit 0.

- [ ] **Step 5: Commit** `feat(playground): pg.py skeleton and init`

---

### Task 2: `validate`

**Files:**
- Modify: `skills/playground/scripts/pg.py`
- Modify: `tests/test-playground.sh`

**Interfaces:**
- Produces:
  - `validate_meta(meta: dict, dir_name: str | None = None) -> list[str]`, which returns human-readable errors (an empty list means valid)
  - `load_meta(path: Path) -> dict`, which raises `PgError` on unreadable or invalid JSON
  - CLI `pg validate [<slug>]`: with no slug it validates every `pg/*/playground.json`. Prints `ok <slug>` or `<slug>: <error>` per problem, and exits 1 if any are invalid.
- Rules:
  - Every spec field is required and unknown keys are errors.
  - Enums are as in Global Constraints. `kind ∈ python|ts|infra|bare`, `mode ∈ guided|autopilot`, `durability ∈ durable|throwaway`, `status ∈ active|concluded|abandoned`.
  - `created` is an ISO date. `concluded` is null or an ISO date.
  - Each question has `id, text, answer, confidence, experiment`. `answer ∈ yes|no|partial|blocked|null` and `confidence ∈ high|medium|low|null`.
  - Rubric keys are exact. Scores are ints 1–5 or null, and `True`/`False` are rejected even though `bool` is an `int` subclass.
  - `slug == dir_name` when `dir_name` is given.
  - If `status == "concluded"`, `verdict` and `concluded` must be non-null and `verdict_draft` must be false.

- [ ] **Step 1: Write failing tests** using a fixture JSON written by a heredoc (a valid active playground):
  - `test_validate_ok`: prints `ok <slug>` and exits 0.
  - `test_validate_bad_enum`: `"verdict": "maybe"` exits 1 and the output contains `verdict`.
  - `test_validate_missing_field`: removing `rubric` exits 1 and the output contains `rubric`.
  - `test_validate_bool_score`: `"dx": true` exits 1.
  - `test_validate_concluded_needs_verdict`: `status: concluded` with `verdict: null` exits 1.
  - `test_validate_slug_mismatch`: a directory name different from `slug` exits 1.
- [ ] **Step 2: Run.** Expected: the new tests FAIL.
- [ ] **Step 3: Implement** `validate_meta`, `load_meta` and the `validate` subcommand.
- [ ] **Step 4: Run.** Expected: all PASS.
- [ ] **Step 5: Commit** `feat(playground): validate playground.json`

---

### Task 3: `new`, project templates, findings template

**Files:**
- Modify: `skills/playground/scripts/pg.py`
- Create: `skills/playground/templates/python/{pyproject.toml,README.md}`
- Create: `skills/playground/templates/ts/{package.json,tsconfig.json,README.md}`
- Create: `skills/playground/templates/infra/{compose.yaml,run.sh,README.md}`
- Create: `skills/playground/templates/bare/README.md`
- Create: `skills/playground/references/findings-template.md`
- Modify: `tests/test-playground.sh`

**Interfaces:**
- Consumes: `repo_root`, `require_playgrounds`, `validate_meta` (Tasks 1–2).
- Produces:
  - `slugify(text: str) -> str`
  - CLI `pg new --tech T --use-case U --kind K --mode M --durability D [--question Q]... [--name N] [--date YYYY-MM-DD]`. It prints only the slug on stdout. `--date` defaults to today and `--name` overrides the text that gets slugified (default `--tech`).
- Slug algorithm: replace `+` with `plus` and `#` with `sharp`. NFKD-normalize and drop non-ASCII. Lowercase. Collapse runs of non-`[a-z0-9]` to `-` and strip `-` from both ends. Truncate to 40 characters and strip a trailing `-`. If the result is empty, raise `PgError("cannot derive a slug from '<text>'; pass --name")`. The full slug is `<date>-<base>`.
- Template placeholders, replaced by plain `str.replace`: `{{slug}}`, `{{tech}}`, `{{use_case}}`, `{{created}}`, `{{questions}}`. **Free-text placeholders (`{{tech}}`, `{{use_case}}`, `{{questions}}`) may appear only in `.md` files.** Non-`.md` files use only `{{slug}}`. Package names are `pg-{{slug}}`.
- Template contents:
  - python: `pyproject.toml` with `requires-python = ">=3.12"`, `[dependency-groups] dev = ["pytest", "ruff"]` and `[tool.pytest.ini_options] testpaths = ["experiments"]`.
  - ts: `package.json` with `"type": "module"`, `"private": true`, scripts `"test": "vitest run"` and devDependencies `typescript`, `vitest`, `tsx` (versions `"latest"`; Claude pins them during research). `tsconfig.json` strict, ES2022, `moduleResolution: "bundler"`.
  - infra: `compose.yaml` with `name: pg-{{slug}}` and `services: {}`, plus a commented example service. `run.sh` (executable): `set -euo pipefail; docker compose up -d "$@"`.
  - Each `README.md` has a title `{{tech}}: {{use_case}}`, the setup command for its kind (`uv sync` / `pnpm install` / `./run.sh`), and an empty "Experiments" table (`| # | Question | Run |`).
- `new` writes `pg/<slug>/` with the rendered template, `experiments/.gitkeep`, `FINDINGS.md` (rendered from `references/findings-template.md`) and `playground.json` (via `json.dumps(indent=2)` plus a newline). `playground.json` is initialized with `status: active`, `version: null`, `concluded: null`, `verdict: null`, `verdict_draft: false`, `compared_with: []`, all rubric values null, and questions `Q1..Qn` with all other question fields null. After writing, `new` asserts `validate_meta(...) == []`.
- `findings-template.md` sections, in order: `# {{tech}}: findings`, then `## Use case` ({{use_case}}), `## Questions` ({{questions}}, rendered per question as `### Qn: text`, then `- Answer: _pending_`, `- Confidence:`, `- Evidence:`), `## Rubric` (a table with all seven rows, `Score` and `Why` columns, score `–`), `## Gotchas`, `## Verdict`, `## Next steps if adopted`.
- Errors: unknown `--kind` → `PgError("unknown kind '<k>' (python|ts|infra|bare)")`. Existing directory → `PgError("playground <slug> already exists; pass --name")`.

- [ ] **Step 1: Write failing tests**
  - `test_new_python`: `pg new --tech httpx --use-case "async client" --kind python --mode guided --durability throwaway --question "Q a" --question "Q b" --date 2026-11-02` prints `2026-11-02-httpx`. The directory contains `pyproject.toml`, `FINDINGS.md`, `experiments/.gitkeep` and `playground.json`. `pg validate 2026-11-02-httpx` exits 0. `playground.json` has 2 questions with ids `Q1`, `Q2`. `FINDINGS.md` contains `### Q2: Q b`.
  - `test_new_each_kind`: kinds `ts`, `infra` and `bare` each succeed and validate. `package.json` passes `python3 -m json.tool`, and `run.sh` is executable.
  - `test_slugify_cases` (via `python3 -c "import sys; sys.path.insert(0, '<scripts>'); import pg; ..."`): `Next.js 15` → `next-js-15`, `C++` → `cplusplus`, `@tanstack/query` → `tanstack-query`, `Ünïcode` → `unicode`, `C#` → `csharp`.
  - `test_slug_empty_errors`: `--tech '+++' --name '!!!'` exits 1 and stderr contains `pass --name`.
  - `test_new_duplicate`: running the same `new` twice → the second exits 1 with stderr containing `already exists`.
  - `test_use_case_special_chars`: with `--kind ts --use-case 'say "hi" | then\nbye'`, `package.json` is still valid JSON and `playground.json.use_case` round-trips exactly.
  - `test_templates_no_freetext_in_code`: `grep -rE '\{\{(tech|use_case|questions)\}\}'` over `templates/` matches only `*.md` files.
- [ ] **Step 2: Run.** Expected: the new tests FAIL.
- [ ] **Step 3: Implement** `slugify`, the template rendering and `new`, and create the template files.
- [ ] **Step 4: Run.** Expected: all PASS.
- [ ] **Step 5: Commit** `feat(playground): new command and project templates`

---

### Task 4: `index` and `findings-files`

**Files:**
- Modify: `skills/playground/scripts/pg.py` (and replace the hard-coded empty `INDEX.md` in `init` with `render_index([])`)
- Modify: `tests/test-playground.sh`

**Interfaces:**
- Consumes: `load_meta`, `validate_meta`.
- Produces:
  - `render_index(metas: list[dict]) -> str`
  - CLI `pg index`: reads every `pg/*/playground.json` in the working tree, writes `INDEX.md` and prints `wrote INDEX.md (<n> playgrounds)`. Each invalid playground produces one stderr line `pg: warning: skipping <slug>: <first error>`, and the exit code stays 0.
  - CLI `pg findings-files <slug>`: prints repo-relative paths, one per line, in this order. `pg/<slug>/playground.json`, `pg/<slug>/FINDINGS.md`, `pg/<slug>/README.md`, then the sorted `pg/<slug>/experiments/*/RESULT.md`. Only files that exist are printed. An unknown slug gives `PgError("no playground <slug>")`.
- `INDEX.md` format:
  - First line `<!-- generated by pg.py index; do not edit -->`, then `# Playgrounds`.
  - One `## <use_case>` section per distinct use case, sorted case-insensitively. Rows within a section are sorted by `created` descending, then slug.
  - Columns: `| Playground | Tech | Version | Status | Verdict | DX | Docs | Perf | Maturity | Eco | Ops | License | Created |`. The Playground cell is a link `[<slug>](pg/<slug>/FINDINGS.md)`.
  - Null is rendered as `–`. The verdict gets ` (draft)` when `verdict_draft` is true.
  - Every cell (and the heading text) is escaped: `|` → `\|`, and newlines → a space.
  - With no playgrounds the body is `_No playgrounds yet._`.

- [ ] **Step 1: Write failing tests**
  - `test_index_groups`: three playgrounds (two sharing use case `orm`, one `queue`, made with `new` and then edited with `python3 -c` JSON edits; one is concluded with verdict `adopt` and `dx: 4`). `INDEX.md` contains `## orm` before `## queue`. The `orm` section lists the newer playground first. A row contains `| adopt |` and `| 4 |`.
  - `test_index_draft_marker`: `verdict: trial` with `verdict_draft: true` → the row contains `trial (draft)`.
  - `test_index_escapes`: a use case `a|b\nc` → a heading line `## a\|b c`, and every table row has exactly 14 unescaped `|` characters.
  - `test_index_skips_invalid`: corrupt one `playground.json` (`{`) → exit 0, stderr contains `pg: warning: skipping`, and the other playgrounds are still listed.
  - `test_index_empty`: after only `init`, `pg index` writes `_No playgrounds yet._`.
  - `test_findings_files`: after creating `experiments/01-a/RESULT.md` and `experiments/01-a/main.py`, the output lists `RESULT.md` and does not list `main.py` or `INDEX.md`.
- [ ] **Step 2: Run.** Expected: the new tests FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: all PASS.
- [ ] **Step 5: Commit** `feat(playground): index and findings-files`

---

### Task 5: `clean`

**Files:**
- Modify: `skills/playground/scripts/pg.py`
- Modify: `tests/test-playground.sh`

**Interfaces:**
- Consumes: `load_meta`-equivalent parsing of `git show <ref>:pg/<slug>/playground.json` output.
- Produces: CLI `pg clean [--base origin/main] [--days 30]`. Prints tab-separated lines, `harvested\t<branch>` first and then `stale\t<branch>\t<age-days>`, with branches as remote-tracking names without `origin/` (e.g. `pg/2026-11-02-httpx`). It prints nothing when nothing qualifies. It does not fetch; the skill runs `git fetch origin --prune` first.
- Algorithm: list `git for-each-ref --format='%(refname:short)%09%(committerdate:unix)' refs/remotes/origin/pg/`. Map each branch to its slug by stripping `origin/pg/` and a trailing `-findings`.
  - **Harvested:** `<base>:pg/<slug>/playground.json` exists and has `status ∈ concluded|abandoned`.
  - **Stale:** not harvested, the branch's own `playground.json` has `status == active`, and the age `(now − committer date) / 86400` is greater than `--days`.
  - Errors: no `origin` remote → `PgError("no 'origin' remote")`. Base ref missing → `PgError("base ref '<base>' not found; run git fetch origin")`.

- [ ] **Step 1: Write failing tests.** Set up a bare remote plus a clone, run `pg init`, commit and push `main`.
  - `test_clean_harvested`: create a playground on branch `pg/<slug>`, push it, then on `main` commit that playground's `playground.json` with `status: concluded`, `verdict: hold`, `concluded` set, and push. `pg clean` prints `harvested\tpg/<slug>`.
  - `test_clean_stale`: an active playground on branch `pg/<slug2>`, committed with `GIT_COMMITTER_DATE="2020-01-01T00:00:00"`, pushed and fetched → output has a line starting with `stale\tpg/<slug2>\t`.
  - `test_clean_fresh_active_ignored`: an active playground committed now → not in the output.
  - `test_clean_findings_branch`: a `pg/<slug>-findings` branch for the harvested slug → also `harvested`.
  - `test_clean_no_origin`: in a repo with no remote → exit 1 and stderr contains `no 'origin' remote`.
- [ ] **Step 2: Run.** Expected: the new tests FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: all PASS.
- [ ] **Step 5: Commit** `feat(playground): clean detects harvested and stale branches`

---

### Task 6: Skill prose (`SKILL.md`, workflow, rubric)

**Files:**
- Create: `skills/playground/SKILL.md`
- Create: `skills/playground/references/workflow-new.md`
- Create: `skills/playground/references/rubric.md`
- Modify: `tests/test-playground.sh` (structure checks)

**Interfaces:**
- Consumes: every `pg.py` command and its output format (Tasks 1–5).

- [ ] **Step 1: Write failing tests**
  - `test_skill_frontmatter`: the `name:` in `SKILL.md` is `playground`, and `description:` is non-empty.
  - `test_skill_mentions_every_command`: `SKILL.md` contains each of `init`, `new`, `resume`, `index`, `compare`, `promote`, `clean`.
  - `test_rubric_has_dimensions`: `rubric.md` contains `DX`, `Docs`, `Performance`, `Maturity`, `Ecosystem`, `Ops cost` and `License`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Write `SKILL.md`.** Frontmatter:
  ```yaml
  name: playground
  description: Use when the user wants to spike, vet, evaluate or try out a language, library, framework, technique or tool for a use case, or runs /playground. Scaffolds a playground in the playgrounds repo, runs question-driven experiments, scores a standard rubric and records a verdict; also resumes, indexes, compares, promotes and cleans playgrounds.
  ```
  Body (under about 150 lines):
  1. **Router**: the first word of the args selects the command (`init|resume|index|compare|promote|clean`), and anything else means `new` with args `<tech> for <use case>`.
  2. **Script path**: `python3 <this skill's base directory>/scripts/pg.py`.
  3. **Preflight**: every command except `init` stops and suggests `/playground init` on the `pg: not a playgrounds repo` error.
  4. One short section per command, following the spec's *Flows*. `new` and conclude point to `references/workflow-new.md`.
  5. **Cloud-session rules**: push after each meaningful step; open PRs as drafts; never delete remote branches (print `git push origin --delete <branch>` commands instead); playgrounds always go in the playgrounds repo.
- [ ] **Step 4: Write `references/workflow-new.md`.**
  - **Interview:** one question per message, with defaults offered. Ask for mode, then durability, then the questions (propose 2–5 from the use case for the user to edit), then an optional playground to compare with. Infer `--kind` from the tech and confirm it.
  - **Steps:**
    1. On a clean, up-to-date `main`, run `pg new …`. It prints the slug. Then run `git switch -c pg/<slug>` (the new untracked files move with you), commit and push. Nothing is committed on `main`.
    2. Research with Context7 and pin the version in `playground.json` and the manifest.
    3. One experiment per question in `experiments/NN-<name>/`. Each has a run command added to the README table and a `RESULT.md` with the command, the captured output and an interpretation.
    4. Guided vs autopilot behavior, including the roughly-3-attempts rule that records `answer: blocked`.
    5. `pg validate <slug>` before every commit.
  - **Conclude:**
    1. Set `status`, `concluded`, `verdict_draft: false`, and remove `DRAFT` from FINDINGS.
    2. Run `pg validate`, then `pg index`.
    3. For a durable playground, open a draft PR from `pg/<slug>` to `main`.
    4. For a throwaway: `git switch -c pg/<slug>-findings origin/main`, `git checkout pg/<slug> -- $(pg findings-files <slug>)`, run `pg index`, commit, push, and open a draft PR.
- [ ] **Step 5: Write `references/rubric.md`.** For each dimension, give its 1/3/5 anchors, then the evidence rule ("cite an experiment or a concrete documented fact; reputation is not evidence; leave null if not assessed").
  - DX: 1 fights you at every step / 3 workable with friction / 5 obvious and fast.
  - Docs: 1 missing or wrong / 3 covers the happy path / 5 covers edge cases with working examples.
  - Performance: 1 fails the use case's needs / 3 adequate / 5 clear headroom. Measured, never assumed.
  - Maturity: 1 pre-1.0 with breaking churn / 3 stable but young / 5 stable for years.
  - Ecosystem: 1 isolated / 3 core integrations exist / 5 rich integrations and community.
  - Ops cost: 1 heavy infra or operational burden / 3 moderate / 5 near zero.
  - License: ok / caution (copyleft, source-available, or usage limits) / blocker.
- [ ] **Step 6: Run** `bash tests/test-playground.sh && claude plugin validate --strict .`. Expected: all PASS and validation succeeds.
- [ ] **Step 7: Commit** `feat(playground): skill instructions, workflow and rubric`

---

### Task 7: End-to-end smoke test and README

**Files:**
- Modify: `tests/test-playground.sh`
- Modify: `README.md` (new "Playgrounds" section after "What's included")

- [ ] **Step 1: Write the smoke test** `test_e2e`. In a fresh repo, run `init`, then `new --kind python` with 2 questions. Edit the JSON to concluded/adopt with every rubric value set, and create `experiments/01-x/RESULT.md`. `validate` exits 0. `index` lists the playground with `adopt`. `findings-files` includes `RESULT.md`.
- [ ] **Step 2: Run.** Expected: PASS (all parts exist by now; this pins the whole path).
- [ ] **Step 3: Update `README.md`.**
  - The purpose, in one paragraph.
  - One-time setup: create an empty GitHub repo (e.g. `playgrounds`), start a cloud session on it, run `/playground init`, then merge.
  - The command list.
  - Durable vs throwaway, in one sentence each.
  - Note that the session cannot delete branches, so `clean` prints the commands.
- [ ] **Step 4: Run every repo test** that needs no network: `for t in tests/test-playground.sh tests/test-vendored.sh tests/test-statusline.sh tests/test-session-start.sh tests/test-install-lists.sh; do bash "$t" || echo "FAILED $t"; done`. Expected: no `FAILED` lines.
- [ ] **Step 5: Commit** `docs: playground skill in README; e2e smoke test`
