# Playgrounds

Technical spikes for vetting languages, libraries, techniques and tools
against a concrete use case. Each playground lives in `pg/<date>-<slug>/`
with its own project files, a `playground.json` and a `FINDINGS.md` that
ends in a verdict: adopt, trial, hold or reject.

`INDEX.md` lists every playground. It is generated, so don't edit it by
hand.

Managed by the `playground` skill in
[berno-works-plugin](https://github.com/dbb613/berno-works-claude-code-plugin).

## Commands

| Command | What it does |
|---|---|
| `/playground <tech> for <use case>` | Interview, scaffold a playground on branch `pg/<slug>`, run experiments |
| `/playground resume <slug>` | Pick up where a playground left off |
| `/playground index` | Rebuild and show `INDEX.md` |
| `/playground compare <slug> <slug>…` | Side-by-side rubric and answers, with a recommendation |
| `/playground promote <slug>` | Turn a concluded throwaway into a durable playground |
| `/playground clean` | List branches that are safe to delete and playgrounds that have gone stale |
| `/playground init` | Set up this repo (already done) |

**Durable** playgrounds merge code and findings into `main`.
**Throwaway** playgrounds merge only their findings. Their code stays on
the `pg/<slug>` branch until you delete it.

## Graduating a playground to its own repo

```sh
git subtree split --prefix pg/<slug> -b graduate/<slug>
git push git@github.com:<you>/<new-repo>.git graduate/<slug>:main
```
