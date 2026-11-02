# Rubric

Every playground is scored on the same dimensions, so playgrounds for the
same use case can be compared side by side. Score **for the stated use
case**, not in general.

## Evidence rule

Every score needs a one-line justification in `FINDINGS.md` that cites
either an experiment (`experiments/NN-*/RESULT.md`) or a concrete documented
fact (release history, a licence text, an issue tracker link). Reputation,
popularity and vibes aren't evidence. If you didn't assess a dimension,
leave it `null` and write "not assessed". A missing score is better than a
guessed one.

## Scored dimensions (1–5)

Anchors for 1, 3 and 5; use 2 and 4 for in-between.

| Dimension (`key`) | 1 | 3 | 5 |
|---|---|---|---|
| **DX** (`dx`) | Fights you at every step: confusing APIs, poor errors | Workable with some friction | Obvious, fast, good errors and types |
| **Docs** (`docs`) | Missing, stale or wrong | Covers the happy path | Covers edge cases with working examples |
| **Performance** (`performance`) | Fails the use case's needs | Adequate with little headroom | Clear headroom for the use case |
| **Maturity** (`maturity`) | Pre-1.0 with breaking churn | Stable but young | Stable for years, careful releases |
| **Ecosystem** (`ecosystem`) | Isolated; you'd build integrations yourself | Core integrations exist | Rich integrations, active community |
| **Ops cost** (`ops_cost`) | Heavy infrastructure or operational burden | Moderate: some services or tuning | Near zero: a library, nothing to run |

**Performance must be measured** in an experiment to score it. Without a
measurement it stays `null`.

## License (`license`)

- `ok`: permissive (MIT, Apache-2.0, BSD, ISC, ...), or fine for the use case.
- `caution`: copyleft (GPL/AGPL/LGPL), source-available (BSL, SSPL, ELv2),
  usage limits or paid tiers that could matter.
- `blocker`: the licence rules out the use case.

## Verdict

- **adopt**: use it for this use case.
- **trial**: promising; use it on something low-risk first.
- **hold**: not now. Record what would change the answer.
- **reject**: unsuitable for this use case.

A `blocker` licence or a failed must-have question means the verdict is at
best **hold**, whatever the scores say.
