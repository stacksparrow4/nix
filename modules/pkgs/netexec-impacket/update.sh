#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq nix

set -euo pipefail

owner="Pennyw0rth"
repo="impacket"
branch="master"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nixfile="$script_dir/default.nix"

echo "Fetching latest commit of $owner/$repo@$branch ..." >&2
latest_rev="$(curl -fsSL "https://api.github.com/repos/$owner/$repo/branches/$branch" | jq -r '.commit.sha')"

if [ -z "$latest_rev" ] || [ "$latest_rev" = "null" ]; then
  echo "Failed to fetch latest commit" >&2
  exit 1
fi

echo "Latest commit: $latest_rev" >&2

current_rev="$(sed -n 's/.*rev = "\([0-9a-f]*\)".*/\1/p' "$nixfile")"
if [ "$current_rev" = "$latest_rev" ]; then
  echo "Already up to date." >&2
  exit 0
fi

echo "Prefetching hash ..." >&2
new_hash="$(nix-prefetch-url --unpack --type sha256 \
  "https://github.com/$owner/$repo/archive/$latest_rev.tar.gz" \
  | xargs nix hash to-sri --type sha256)"

echo "New hash: $new_hash" >&2

sed -i \
  -e "s|rev = \"$current_rev\"|rev = \"$latest_rev\"|" \
  -e "s|hash = \"[^\"]*\"|hash = \"$new_hash\"|" \
  "$nixfile"

echo "Updated $nixfile" >&2
