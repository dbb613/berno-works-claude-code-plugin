#!/usr/bin/env bash
# Re-fetch every skill in scripts/vendored.tsv at upstream HEAD into skills/<folder>/.
# Folders whose upstream SHA is unchanged are left untouched, so a rerun is a no-op.
# Review the resulting git diff before committing.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
status=0

while IFS=$'\t' read -r folder repo path license; do
  if [ -z "$folder" ] || [ "${folder#\#}" != "$folder" ]; then continue; fi
  dest="$root/skills/$folder"

  if ! sha="$(gh api "repos/$repo/commits/HEAD" --jq .sha)"; then
    echo "error: could not resolve HEAD of $repo; skipping $folder" >&2
    status=1; continue
  fi
  if grep -qx -- "- Commit: $sha" "$dest/UPSTREAM.md" 2>/dev/null; then
    echo "$folder: up to date ($sha)"
    continue
  fi

  clone="$work/$folder"
  if ! { git clone -q --depth 1 --filter=blob:none --sparse "https://github.com/$repo.git" "$clone" &&
         git -C "$clone" sparse-checkout set -- "$path" &&
         [ -f "$clone/$path/SKILL.md" ]; }; then
    echo "error: could not fetch $repo/$path; leaving $folder untouched" >&2
    status=1; continue
  fi

  rm -rf "$dest"
  mkdir -p "$dest"
  cp -R "$clone/$path/." "$dest/"
  cat > "$dest/UPSTREAM.md" <<MD
# Upstream source

Vendored unchanged by \`scripts/update-vendored.sh\`. Do not edit by hand.

- Repository: https://github.com/$repo
- Path: $path
- Commit: $(git -C "$clone" rev-parse HEAD)
- License: $license
- Fetched: $(date -u +%Y-%m-%d)
MD
  echo "$folder: updated to $sha"
done < "$root/scripts/vendored.tsv"

exit $status
