---
name: playground
description: Use when the user wants to spike, vet, evaluate or try out a language, library, framework, technique or tool for a use case, or runs /playground. Scaffolds a playground in the playgrounds repo, runs question-driven experiments, scores a standard rubric and records a verdict; also resumes, indexes, compares, promotes and cleans playgrounds.
---

# Playground

A playground is a spike that answers one thing: **is this tech suitable for
this use case?** It leaves behind runnable experiments *and* a findings record
(answers, rubric, verdict). All playgrounds live in one **playgrounds repo**,
in `pg/<yyyy-mm-dd>-<slug>/`, each on its own branch `pg/<slug>`. You run
locally, in the user's clone of that repo, with `git` and `gh` available.

## The script

Every mechanical step goes through `pg.py`. Never hand-roll what it does.

```sh
PG="python3 <this skill's base directory>/scripts/pg.py"
```

| Command | Does |
|---|---|
| `$PG init` | Adds `.playgrounds`, `README.md`, `INDEX.md`, `.gitignore` (never overwrites) |
| `$PG new --tech=T --use-case=U --kind=python\|ts\|infra\|bare --mode=guided\|autopilot --durability=durable\|throwaway [--question=Q]... [--name=N]` (always `--flag=value`) | Scaffolds `pg/<slug>/`, prints the slug |
| `$PG validate [<slug>]` | Checks `playground.json`; run before every commit |
| `$PG index` | Regenerates `INDEX.md` |
| `$PG findings-files <slug> [--ref <git-ref>]` | Paths a throwaway merges to `main` (`--ref` reads from a branch, not the working tree) |
| `$PG clean` | `harvested\t<branch>\t<where>` / `stale\t<branch>\t<days>\t<where>` lines; `<where>` is `local`, `remote` or `both` |

Errors are one `pg: ...` line with exit 1. If one says `not a playgrounds
repo`, stop and tell the user to `cd` into their playgrounds clone, or set
one up with `/playground init`.

## Routing

The first word of the arguments picks the command: `init`, `resume`,
`index`, `compare`, `promote`, `clean`. Anything else is **new**, read as
`<tech> for <use case>` (ask for whichever part is missing).

## Commands

**init**: If the current directory isn't a git repo, offer to create one:
`gh repo create playgrounds --private --add-readme --clone` (the user picks
the name and location), then `cd` into it. Then:
- **Origin has a `main`:** run `$PG init` on a branch from it, commit, push,
  and open a draft PR into `main` (`gh pr create --draft`), or commit
  straight to `main` if the user prefers.
- **No branches yet** (an empty repo, or no remote): `git switch -c main`,
  run `$PG init`, commit, and push `main` if there is an origin.

**new**: Follow `references/workflow-new.md` exactly: interview → scaffold →
research → experiments → conclude.

**resume `<slug>`**: `git fetch origin`. Check out `pg/<slug>` if it exists
locally or on origin, otherwise stay on `main`. Read `playground.json` and
`FINDINGS.md`, then tell the user the state in three lines: open questions,
what was last done, and what's next. Continue in the recorded `mode`. If the
code branch is gone (a harvested throwaway), say only findings can be
extended.

**index**: Run `$PG index` on an up-to-date `main` and show the table. For
filters ("only adopted", "only ts"), read the `playground.json` files and
filter in chat. Commit `INDEX.md` only if it changed and the user wants it.

**compare `<slug> <slug>...`**: Read each `playground.json` and
`FINDINGS.md`. Show a side-by-side rubric table, then answers to questions
that overlap in meaning, then a recommendation for the shared use case with
the deciding reasons. Offer to save it as `compare/<yyyy-mm-dd>-<topic>.md`
and to add the other slugs to each playground's `compared_with` (validate,
commit, open a draft PR with `gh pr create --draft`).

**promote `<slug>`**: Only for a concluded throwaway whose `pg/<slug>` branch
still exists (locally or on origin); otherwise refuse and explain. Its findings are
usually already on `main`, so merge `main` in first, keeping the branch's
versions of the files both sides added:

```sh
git fetch origin && git switch pg/<slug>
git merge -X ours --no-edit origin/main
```

Then set `durability: durable`, run `$PG validate <slug>` and `$PG index`,
commit, push, and open a draft PR from `pg/<slug>` to `main`.

**clean**: `git fetch origin --prune`, then `$PG clean`. Show both lists,
then act on what the user confirms:
- **Safe to delete** (findings already on `main`): delete each branch the
  user approves, matching `<where>`: `git branch -D <branch>` for `local`,
  `git push origin --delete <branch>` for `remote`, both for `both`.
  Mention that deleting a throwaway's code branch drops its code for good;
  `promote` it first to keep it.
- **Stale** (active, untouched for more than 30 days): for each, offer to
  conclude it (see the workflow) or mark it `abandoned` (set `status`,
  validate, then a findings PR like a throwaway).

## Rules

- **Commit after every meaningful step.** Push a branch when it needs a PR,
  or when the user wants a backup. A throwaway's code branch can stay
  local-only. Open PRs as drafts with `gh pr create --draft`.
- **Delete branches only after the user confirms**, and only the ones
  `$PG clean` reports.
- **Evidence over reputation.** Answers and rubric scores cite an experiment's
  `RESULT.md` or a concrete documented fact. Scoring is defined in
  `references/rubric.md`.
- `FINDINGS.md` follows `references/findings-template.md`. Keep its sections.
- Never commit playground work directly on `main`; it goes on `pg/<slug>` or
  `pg/<slug>-findings` and reaches `main` by PR.
