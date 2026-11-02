# Playground skill: design

Date: 2026-11-02
Status: approved in conversation, pending written-spec review

## Purpose

Cut the friction of building technical "playgrounds", meaning spikes that
vet a new language, library, technique, or tool against a concrete use case
and end in a decision. A playground leaves behind **both** runnable
reference code **and** a structured findings record, and the two are
linked.

Success looks like this:

- From an empty cloud session to a scaffolded, committed playground with a
  first runnable experiment, in one command plus a short interview.
- Every concluded playground has an answered question list, a rubric score
  and a verdict that can be compared with other playgrounds.
- Findings survive even when the code is thrown away.

## Constraints

- **Runs mostly in Claude Code cloud sessions.** Containers are ephemeral
  and sessions are bound to repos attached at start. A session cannot
  create GitHub repos or delete remote branches. Anything worth keeping
  must be committed and pushed.
- **Tech scope for templates:** Python libraries, JS/TS libraries and
  frameworks, tools/services/infra. Anything else uses a bare template and
  Claude improvises.
- The skill ships in this plugin (`berno-works-plugin`) at user scope.

## Decisions

| Topic | Decision |
|---|---|
| Output | Code and findings, equally |
| Storage | One GitHub repo (e.g. `dbb613/playgrounds`), one directory and one branch per playground |
| Durability | Chosen at creation: durable or throwaway |
| Evaluation | Per-playground questions plus a fixed standard rubric |
| Autonomy | Chosen at creation: guided (pair) or autopilot |
| Lifecycle v1 | new, resume, index, compare, promote, clean, plus init |

Alternatives that were rejected: a real repo per playground (needs a token
secret plus `add_repo` on each creation, which is too much friction in cloud
sessions) and a hybrid of the two storage models (two code paths).

## Components

### In this plugin

```
skills/playground/
  SKILL.md                  # router: new | resume | index | compare | promote | clean | init
  references/
    workflow-new.md         # interview → scaffold → research → experiments → conclude
    rubric.md               # rubric definition and scoring rules
    findings-template.md    # FINDINGS.md skeleton
  templates/
    python/                 # uv project, pytest, ruff
    ts/                     # pnpm, node/vite, vitest
    infra/                  # compose.yaml + run.sh
    bare/                   # README + experiments/ only
  scripts/
    pg.py                   # deterministic operations (stdlib-only Python 3)
tests/
  test-playground.sh        # runs pg.py tests against temp git repos
```

**Who does what:** `pg.py` does the deterministic work: slug generation,
creating directories, rendering templates, validating `playground.json`,
regenerating `INDEX.md`, detecting stale or harvested branches, and
building the throwaway "findings-only" file list. `SKILL.md` and its
references cover the judgment work: the interview, Context7 research,
writing and running experiments, scoring, and the verdict.

`pg.py` subcommands:

| Command | Effect |
|---|---|
| `pg.py init` | Writes `README.md`, `INDEX.md`, `.gitignore`, and `.playgrounds` marker into the repo root; no-op if present |
| `pg.py new --tech T --use-case U --kind K --mode M --durability D` | Creates `pg/<yyyy-mm-dd>-<slug>/` from template `K`, writes `playground.json` and `FINDINGS.md`; prints the slug |
| `pg.py index` | Rebuilds `INDEX.md` from every `pg/*/playground.json` in the working tree |
| `pg.py findings-files <slug> [--ref R]` | Prints the paths that a throwaway merges to `main`; `--ref` reads them from a git ref instead of the working tree |
| `pg.py clean` | Lists `pg/*` remote branches whose playground is concluded on `main`, and active playgrounds with no commit for 30 days |
| `pg.py validate [<slug>]` | Checks `playground.json` against the schema |

Errors: exit non-zero with a single plain-language line on stderr (slug
exists, not a playgrounds repo, unknown template, invalid metadata).

### In the playgrounds repo

```
.playgrounds                # marker file: identifies an initialized playgrounds repo
README.md
INDEX.md                    # generated; do not hand-edit
compare/                    # saved comparisons
pg/<yyyy-mm-dd>-<slug>/
  playground.json
  FINDINGS.md
  README.md                 # one run command per experiment
  experiments/
    01-<name>/
      RESULT.md             # captured output + interpretation
  pyproject.toml | package.json | compose.yaml
```

Each playground directory is self-contained: it has its own dependency
manifest and lockfile, and does not share a workspace with the others.

## Data formats

### playground.json

```json
{
  "slug": "2026-11-02-drizzle-orm",
  "tech": "drizzle-orm",
  "version": "0.44.x",
  "kind": "python | ts | infra | bare",
  "use_case": "typed SQL layer for a Postgres-backed Next.js app",
  "mode": "guided | autopilot",
  "durability": "durable | throwaway",
  "status": "active | concluded | abandoned",
  "created": "2026-11-02",
  "concluded": null,
  "questions": [
    {
      "id": "Q1",
      "text": "Does it handle migrations without a separate CLI?",
      "answer": "yes | no | partial | blocked | null",
      "confidence": "high | medium | low | null",
      "experiment": "02-migrations"
    }
  ],
  "rubric": {
    "dx": null, "docs": null, "performance": null,
    "maturity": null, "ecosystem": null, "ops_cost": null,
    "license": "ok | caution | blocker | null"
  },
  "verdict": "adopt | trial | hold | reject | null",
  "verdict_draft": false,
  "compared_with": []
}
```

### Rubric

Six dimensions are scored as integers from 1 to 5, or `null` if not
assessed: **DX, Docs, Performance, Maturity, Ecosystem, Ops cost**. A
seventh, **License**, is `ok`, `caution`, or `blocker`. Each score in
`FINDINGS.md` needs a one-line justification that points to something
observed in an experiment, or to a concrete documented fact (a release
date, a licence text). Reputation alone isn't evidence. `references/rubric.md`
defines what 1, 3 and 5 mean for each dimension.

### FINDINGS.md sections

1. Use case
2. Questions: each with its answer, confidence, and evidence (a link to the
   experiment `RESULT.md`)
3. Rubric: a table plus a justification per score
4. Gotchas
5. Verdict and reasoning (marked **DRAFT** until the user confirms it)
6. Next steps if adopted

### Verdicts

`adopt` (use it for this use case), `trial` (promising, use it on something
low-risk), `hold` (not now; the reason is recorded), `reject` (unsuitable
for this use case).

## Flows

All commands start by checking that the working repo has `.playgrounds`.
If it doesn't, they stop and suggest `/playground init`.

### init

The repo's default branch must be `main`. If origin has no branches, create
`main`, run `pg.py init`, commit, and push `main`. Otherwise run `init` on a
branch and open a PR into `main`. If pushing `main` is refused, ask the user
to create the repo with a README.

### new: `/playground <tech> for <use case>`

1. **Interview**, one question at a time, with defaults offered: mode,
   durability, the questions (Claude proposes 2–5 from the use case and the
   user edits them), and optionally an existing playground to compare
   against. The template kind is inferred from the tech and confirmed.
2. Create branch `pg/<slug>` from `main`.
3. Run `pg.py new` to scaffold.
4. **Research:** Context7 docs for the tech; record the pinned version in
   `playground.json`.
5. **Experiments**, one per question, in `experiments/NN-<name>/`:
   - **Guided:** Claude writes and runs experiment 01 as a starting point,
     then pairs with the user and updates `FINDINGS.md` as answers come in.
   - **Autopilot:** Claude builds and runs every experiment, records
     `RESULT.md` for each, fills in answers and rubric, and drafts the
     verdict (`verdict_draft: true`). If an experiment still fails after
     about 3 genuine attempts, its answer becomes `blocked` and the reason
     is recorded as a finding. No workarounds that would invalidate the
     result.
6. Commit and push to `pg/<slug>` after each meaningful step.

### conclude

Triggered when the user says done (guided) or when autopilot finishes and
the user confirms the verdict.

1. Set `status: concluded`, `concluded: <date>`, `verdict_draft: false`;
   remove the DRAFT marker.
2. Run `pg.py index`.
3. Open a draft PR to `main`:
   - **Durable:** the whole branch.
   - **Throwaway:** a new branch `pg/<slug>-findings` from `main` containing
     only the `pg.py findings-files --ref origin/pg/<slug>` paths (`playground.json`,
     `FINDINGS.md`, `README.md`, `experiments/*/RESULT.md`) plus `INDEX.md`.
     The code stays on `pg/<slug>`.

### resume `<slug>`

Check out `pg/<slug>` if it exists, otherwise use `main`. Read
`playground.json` and `FINDINGS.md`, summarize the state in three lines,
and continue in the recorded mode. If the code branch is gone, say so;
only the findings can be extended.

### index

Run `pg.py index` and show `INDEX.md`. It has one table grouped by use
case, with columns for slug, tech, version, verdict, the six rubric scores,
licence, and date. Filtering (`--verdict`, `--kind`, `--status`) happens
in-chat from `playground.json` data.

### compare `<slug> <slug> …`

Show a side-by-side rubric table, answers to questions that overlap
(matched by Claude on meaning), then a recommendation for the shared use
case. Optionally save the result to `compare/<date>-<topic>.md` and append
the slugs to each playground's `compared_with`.

### promote `<slug>`

For a concluded throwaway whose `pg/<slug>` branch still exists: merge
`origin/main` into it with `-X ours` (the findings PR already added the same
files), set `durability: durable`, re-index, and open a PR that merges the
code. If the branch is
gone, refuse and explain why.

### clean

Run `pg.py clean` and present two lists: branches that are safe to delete
(their findings are on `main`), and stale active playgrounds (offer to
conclude or abandon each one). The session can't delete remote branches,
so print the `git push origin --delete …` commands for the user to run, or
point them to GitHub's branch page.

## Testing

`tests/test-playground.sh` follows the existing shell-test convention. It
creates temporary git repos (a bare "remote" plus a clone) and checks:

- `init` writes the expected files and is idempotent
- `new` creates the directory per template, with valid `playground.json`,
  and rejects a duplicate slug
- `validate` rejects bad enum values and a missing field
- `index` output for a fixture with several playgrounds (grouping and
  columns)
- `findings-files` returns exactly the findings paths
- `clean` detects a harvested branch and a stale active playground
- errors outside an initialized repo

An end-to-end smoke test runs `init` → `new` → edit metadata → `index`. The
skill's prose flows are checked by hand in a real cloud session on the
playgrounds repo.

## Out of scope for v1

- Creating a GitHub repo per playground ("graduate"); documented as a
  manual step in the playgrounds README.
- Automatic branch deletion.
- Templates for whole new languages (Rust, Go, …); these use `bare`.
- Benchmark harnesses beyond what an experiment writes itself.
