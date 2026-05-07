#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <newversion>" >&2
    exit 1
fi

NEW_VERSION="$1"
NIX_FILE="$(dirname "$(readlink -f "$0")")/default.nix"

FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

# Extract current values
CURRENT_VERSION=$(grep -E '^\s*version\s*=' "$NIX_FILE" | sed -E 's/.*"([^"]+)".*/\1/')
CURRENT_SRC_HASH=$(awk '/fetchFromGitHub/,/};/' "$NIX_FILE" | grep -E '^\s*hash\s*=' | sed -E 's/.*"([^"]+)".*/\1/')
CURRENT_NPM_HASH=$(awk '/fetchNpmDeps/,/};/' "$NIX_FILE" | grep -E '^\s*hash\s*=' | sed -E 's/.*"([^"]+)".*/\1/')

echo "Current version: $CURRENT_VERSION"
echo "New version:     $NEW_VERSION"

# Replace version and zero out hashes so nix will report the correct ones
sed -i \
    -e "s|version = \"$CURRENT_VERSION\"|version = \"$NEW_VERSION\"|" \
    -e "s|hash = \"$CURRENT_SRC_HASH\"|hash = \"$FAKE_HASH\"|" \
    -e "s|hash = \"$CURRENT_NPM_HASH\"|hash = \"$FAKE_HASH\"|" \
    "$NIX_FILE"

get_real_hash() {
    # Run nix-build, capture stderr, extract the "got: sha256-..." line
    local output
    output=$(nix-build --no-out-link "$NIX_FILE" 2>&1 || true)
    echo "$output" | grep -oE 'got:\s+sha256-[A-Za-z0-9+/=]+' | head -n1 | awk '{print $2}'
}

echo "Fetching new src hash..."
NEW_SRC_HASH=$(get_real_hash)
if [ -z "$NEW_SRC_HASH" ]; then
    echo "Failed to determine new src hash" >&2
    exit 1
fi
echo "New src hash: $NEW_SRC_HASH"
# Replace only the first FAKE_HASH occurrence (the src hash)
sed -i "0,/hash = \"$FAKE_HASH\"/{s|hash = \"$FAKE_HASH\"|hash = \"$NEW_SRC_HASH\"|}" "$NIX_FILE"

echo "Fetching new npmDeps hash..."
NEW_NPM_HASH=$(get_real_hash)
if [ -z "$NEW_NPM_HASH" ]; then
    echo "Failed to determine new npmDeps hash" >&2
    exit 1
fi
echo "New npmDeps hash: $NEW_NPM_HASH"
sed -i "s|hash = \"$FAKE_HASH\"|hash = \"$NEW_NPM_HASH\"|" "$NIX_FILE"

echo "Verifying build..."
nix-build --no-out-link "$NIX_FILE"
echo "Done."
