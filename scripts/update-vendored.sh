#!/usr/bin/env bash
# Re-fetch every skill in scripts/vendored.tsv at upstream HEAD into skills/<folder>/.
# A skill is identified by the last upstream commit that touched its own path, so folders
# whose skill hasn't changed upstream are left untouched and a rerun is a no-op.
# Review the resulting git diff before committing.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
status=0

while IFS=$'\t' read -r folder repo path license; do
  if [ -z "$folder" ] || [ "${folder#\#}" != "$folder" ]; then continue; fi
  dest="$root/skills/$folder"

  if ! sha="$(gh api "repos/$repo/commits?path=$path&per_page=1" --jq '.[0].sha' </dev/null)" || [ -z "$sha" ]; then
    echo "error: could not resolve the last commit for $repo/$path; skipping $folder" >&2
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

  if [ -n "$(find "$clone/$path" -type l)" ]; then
    echo "error: $repo/$path contains symlinks; refusing to vendor $folder" >&2
    status=1; continue
  fi
  rm -rf "$dest"
  mkdir -p "$dest"
  cp -R "$clone/$path/." "$dest/"
  # MIT requires the copyright notice to travel with the copy.
  license_file="$(cd "$clone" && ls LICENSE* LICENCE* 2>/dev/null | head -1 || true)"
  # Refuse symlinks: an upstream LICENSE linking to a local file would copy that file here.
  if [ -n "$license_file" ] && [ -f "$clone/$license_file" ] && [ ! -L "$clone/$license_file" ]; then
    cp "$clone/$license_file" "$dest/LICENSE.upstream"
    license_source="LICENSE.upstream (copied from the repository root)"
  else
    license_source="the \`license:\` field in SKILL.md frontmatter; the repository has no LICENSE file"
  fi
  cat > "$dest/UPSTREAM.md" <<MD
# Upstream source

Vendored unchanged by \`scripts/update-vendored.sh\`. Do not edit by hand.

- Repository: https://github.com/$repo
- Path: $path
- Commit: $sha
- License: $license
- License source: $license_source
- Fetched: $(date -u +%Y-%m-%d)
MD
  echo "$folder: updated to $sha"
done < "$root/scripts/vendored.tsv"

exit $status
