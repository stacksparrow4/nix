#!/usr/bin/env nix
#! nix shell nixpkgs#jq --command bash

set -e
cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null

YELLOW=$(echo -e '\x1b[33m')
GREEN=$(echo -e '\x1b[32m')
RED=$(echo -e '\x1b[31m')
RESET=$(echo -e '\x1b[0m')

old=$(nix eval --raw --impure --expr '"${(builtins.getFlake "'"$(pwd)"'").inputs.nixpkgs-unstable}"')
new=$(nix eval --raw --impure --expr 'fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz"')

while read pp; do
  while read rf; do
    echo "$YELLOW$rf$RESET" >&2
    if ! [ -f "$new/$rf" ]; then
      echo "$RED[REMOVED]$RESET" >&2
    elif cmp --silent "$old/$rf" "$new/$rf"; then
      echo "$GREEN[UNCHANGED]$RESET" >&2
    else
      diff -u "$old/$rf" "$new/$rf" | ydiff || true
    fi
  done < <(cd "$old"; find "$pp" -type f)
done < <(cat protected.json | jq -r '.[]')

