#!/usr/bin/env bash
# Checks every vendored skill listed in scripts/vendored.tsv is present and loadable.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
while IFS=$'\t' read -r folder repo path license; do
  [ -z "$folder" ] || [ "${folder#\#}" != "$folder" ] && continue
  dir="$root/skills/$folder"
  if [ ! -f "$dir/SKILL.md" ]; then echo "FAIL $folder: missing SKILL.md"; fail=1; continue; fi
  name="$(sed -n 's/^name:[[:space:]]*//p' "$dir/SKILL.md" | head -1 | tr -d '"'"'")"
  [ "$name" = "$folder" ] || { echo "FAIL $folder: frontmatter name is '$name'"; fail=1; }
  grep -q "^- Commit: [0-9a-f]\{40\}$" "$dir/UPSTREAM.md" 2>/dev/null || { echo "FAIL $folder: UPSTREAM.md lacks commit SHA"; fail=1; }
  { [ -s "$dir/LICENSE.upstream" ] || grep -q "^- License source: " "$dir/UPSTREAM.md" 2>/dev/null; } || { echo "FAIL $folder: no upstream license notice"; fail=1; }
  grep -q "^- Repository: https://github.com/$repo$" "$dir/UPSTREAM.md" 2>/dev/null || { echo "FAIL $folder: UPSTREAM.md lacks repository"; fail=1; }
done < "$root/scripts/vendored.tsv"
[ $fail -eq 0 ] && echo "PASS vendored skills"
exit $fail
