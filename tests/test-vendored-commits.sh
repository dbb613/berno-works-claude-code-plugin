#!/usr/bin/env bash
# Network test: each vendored skill records the last upstream commit that touched its own path,
# so update-vendored.sh only rewrites a skill when that skill changed.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
while IFS=$'\t' read -r folder repo path license; do
  if [ -z "$folder" ] || [ "${folder#\#}" != "$folder" ]; then continue; fi
  want="$(gh api "repos/$repo/commits?path=$path&per_page=1" --jq '.[0].sha' </dev/null)"
  grep -qx -- "- Commit: $want" "$root/skills/$folder/UPSTREAM.md" || { echo "FAIL $folder: UPSTREAM.md commit is not $want"; fail=1; }
done < "$root/scripts/vendored.tsv"
[ $fail -eq 0 ] && echo "PASS vendored commits track skill paths"
exit $fail
