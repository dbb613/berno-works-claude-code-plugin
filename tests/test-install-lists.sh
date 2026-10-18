#!/usr/bin/env bash
# Checks scripts/install.sh lists exactly the marketplaces and dependencies the manifests declare.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$root" <<'PY'
import json, re, sys
root = sys.argv[1]
plugin = json.load(open(f"{root}/.claude-plugin/plugin.json"))
market = json.load(open(f"{root}/.claude-plugin/marketplace.json"))
script = open(f"{root}/scripts/install.sh").read()

def array(name: str) -> list[str]:
    m = re.search(rf"^{name}=\((.*?)\)", script, re.S | re.M)
    return m.group(1).split() if m else []

want_deps = [f"{d['name']}@{d['marketplace']}" for d in plugin["dependencies"]]
got_deps = array("DEPENDENCIES")
got_repos = array("MARKETPLACE_REPOS")
fails = []
if got_deps != want_deps:
    fails.append(f"DEPENDENCIES {got_deps} != plugin.json {want_deps}")
if len(got_repos) != len(market["allowCrossMarketplaceDependenciesOn"]):
    fails.append(f"MARKETPLACE_REPOS has {len(got_repos)} entries, allowlist has {len(market['allowCrossMarketplaceDependenciesOn'])}")
for f in fails: print("FAIL", f)
print("PASS install lists" if not fails else f"{len(fails)} FAILED")
sys.exit(len(fails))
PY
