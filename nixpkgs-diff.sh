#!/bin/sh

set -e
cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null

before=$(mktemp)
after=$(mktemp)

getnixpkgsfiles() {
  nix build --dry-run -v '.#nixosConfigurations.nest01.config.system.build.toplevel' 2>&1 | grep -E '^evaluating file' | cut -d"'" -f2 | grep -F "$(nix eval --raw --impure --expr '(builtins.getFlake "path://'$(pwd)'").inputs.nixpkgs.outPath')" | grep -E '\.nix$' | sed -E 's/^\/nix\/store\/[^\/]+\///' | sort -u
}

getnixpkgsfiles > "$before"
cp flake.lock flake.lock.bak
nix flake update

if ! getnixpkgsfiles > "$after"; then
  mv flake.lock.bak flake.lock
  exit 1
fi

mv flake.lock.bak flake.lock

if diff "$before" "$after" &>/dev/null; then
  echo "No new files were added"
else
  echo "File differences:"
  ydiff "$before" "$after"
fi

# TODO: use `comm -12` to find common lines or added lines and then display them
