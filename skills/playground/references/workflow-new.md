# New playground workflow

## 1. Interview

Ask **one question per message** and offer a default each time. Keep it fast:
the point is low friction.

1. **Mode**: *guided* (you scaffold and write experiment 01, then pair) or
   *autopilot* (you build and run every experiment and draft the verdict).
   Default: guided.
2. **Durability**: *durable* (code and findings merge to `main`) or
   *throwaway* (only findings merge; code stays on its branch). Default:
   throwaway.
3. **Questions**: propose 2–5 concrete, answerable questions derived from the
   use case (e.g. "Can it stream responses with back-pressure?", "p95 latency
   under 1k rps on one core?"). The user edits, adds or drops them. Each
   question becomes one experiment.
4. **Compare with** (optional): if `INDEX.md` lists playgrounds with the same
   or similar use case, offer to compare at the end.

Infer `--kind` from the tech (Python library → `python`; JS/TS → `ts`;
database, queue, CLI, service → `infra`; anything else → `bare`) and state it
in your summary so the user can correct it.

## 2. Scaffold

On a clean, up-to-date `main` (`git switch main && git pull`):

```sh
$PG new --tech "<tech>" --use-case "<use case>" --kind <kind> \
  --mode <mode> --durability <durability> --question "<q1>" --question "<q2>"
git switch -c pg/<slug>          # the untracked new files come along
git add pg/<slug> && git commit -m "pg(<slug>): scaffold" && git push -u origin pg/<slug>
```

Nothing is ever committed on `main` directly.

## 3. Research

Use Context7 (or the official docs) for the tech's **current** version. Pin it:
set `version` in `playground.json` and pin the dependency in the manifest
(`pyproject.toml`, `package.json` (replace `"latest"`), or the image tag in
`compose.yaml`). Install and confirm a hello-world runs before writing
experiments.

## 4. Experiments

One directory per question: `experiments/NN-<short-name>/` (`01-streaming`,
`02-migrations`). Each one:

- answers exactly one question and is as small as possible;
- runs with **one command**, added to the README's Experiments table
  (`| 01 | Q1: ... | uv run python experiments/01-streaming/main.py |`);
- gets a `RESULT.md` with: the command, the captured output (trimmed), and
  a short interpretation. `RESULT.md` is the evidence that survives even when
  the code is thrown away;
- sets the question's `experiment` field to its directory name.

After each answered question, update `playground.json` (`answer`,
`confidence`) and the question's section in `FINDINGS.md`, run
`$PG validate <slug>`, commit and push.

**Guided:** write and run experiment 01 yourself as a working starting point,
show the result, then pair: the user drives, you help, and you keep
`FINDINGS.md` and `playground.json` current as answers emerge.

**Autopilot:** build and run every experiment, then fill in answers, the
rubric (per `rubric.md`), gotchas and a verdict. Set `verdict_draft: true`
and put **DRAFT** at the top of the Verdict section. If an experiment still
fails after about 3 genuine attempts, stop: set `answer: blocked`, write what
blocked it in `RESULT.md` and Gotchas. Don't work around a block in a way
that would make the answer meaningless. Being blocked is itself a finding.
Then present the draft verdict and ask the user to confirm or change it.

## 5. Conclude

When the user says they're done (guided) or confirms the draft (autopilot):

1. Fill any remaining rubric scores (or leave `null` with "not assessed").
2. Set `status: concluded`, `concluded: <today>`, `verdict`, and
   `verdict_draft: false`. Remove **DRAFT** from `FINDINGS.md`. Write the
   verdict reasoning and "Next steps if adopted".
3. `$PG validate <slug>`, then commit and push the branch.
4. Merge to `main` by draft PR:
   - **Durable:**
     ```sh
     git fetch origin && git merge --no-edit origin/main   # so the index includes everything merged since
     $PG index && git add INDEX.md && git commit -m "pg(<slug>): index" && git push
     ```
     If that merge conflicts only in `INDEX.md`, take either side and let
     `$PG index` regenerate it.
     then open a PR from `pg/<slug>` to `main`.
   - **Throwaway:** findings only.
     ```sh
     git fetch origin
     files=$($PG findings-files <slug> --ref origin/pg/<slug>) && [ -n "$files" ]   # stop if this fails
     git switch -c pg/<slug>-findings origin/main
     git checkout origin/pg/<slug> -- $files
     $PG index
     git add -A && git commit -m "pg(<slug>): findings" && git push -u origin pg/<slug>-findings
     ```
     Run these one at a time and check each succeeded. In particular, never
     run `git checkout origin/pg/<slug> --` with an empty file list: that
     switches branches instead of copying files.
     then open a PR from `pg/<slug>-findings` to `main`. Tell the user the code
     stays on `pg/<slug>` until `/playground clean`, and `/playground promote`
     can still bring it in.

   If `INDEX.md` conflicts with another merged PR later, re-run `$PG index`
   on the merged result instead of hand-merging the table.
5. If the user asked to compare, run the compare flow from `SKILL.md`.
