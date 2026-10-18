# TODO

## Upstream: dependency install bug

Claude Code 2.1.302 installs only one missing plugin dependency per
`claude plugin install` / `marketplace add`, and only from marketplaces
already added. `scripts/install.sh` works around this.

- [ ] Watch for a fix in Claude Code release notes (bug report drafted 2026-10-17).
- [ ] Once fixed, re-test the plain install on a fresh `CLAUDE_CONFIG_DIR`:
      `claude plugin marketplace add dbb613/berno-works-claude-code-plugin`
      then `claude plugin install berno-works-plugin@berno-works`.
- [ ] If every dependency installs, simplify `install.sh` or drop it, and update
      the README install section and `tests/test-install-*.sh`.

## Deferred review findings (minor)

- [ ] `install.sh`: fail early with a clear message when `claude` isn't on PATH.
- [ ] `install.sh`: wrap the body in `main() { …; }; main "$@"` so `curl | bash`
      stays safe if a future `claude` command reads stdin.
- [ ] `tests/test-install-lists.sh`: check each repo maps to the marketplace name
      used in `DEPENDENCIES`, not just the count.
- [ ] `tests/test-session-start.sh`: exercise the actual `hooks/hooks.json`
      command string with a spaced plugin root.
- [ ] `update-vendored.sh`: give `gh`/`git` `</dev/null` inside the read loop.
- [ ] `update-vendored.sh`: remove folders for rows dropped from `vendored.tsv`;
      avoid a half-copied folder if `cp -R` fails.
- [ ] Consider moving the plugin into a subfolder so `docs/`, `tests/` and
      `scripts/` don't ship into users' plugin cache.
- [ ] Verify what happens when a dependency is installed but disabled.
- [ ] Add a test for the symlink refusal in `update-vendored.sh`.
