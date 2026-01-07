#!/bin/sh

set -e

for inputname in nixpkgs nixpkgs-unstable; do
  echo "=================================================="
  echo "=================================================="
  echo "CHECKING FOR CHANGES FOR INPUT $inputname:"

  nix build --dry-run -v ".#nixosConfigurations.$(hostname).config.system.build.toplevel" || { echo "Failed to build!"; exit 1; }

  before=$(mktemp)
  after=$(mktemp)

  getnixpkgspath() {
    nix eval --raw --impure --expr '(builtins.getFlake "path://'"$(pwd)"'").inputs.'"$inputname"'.outPath'
  }

  getnixpkgsfiles() {
    nix build --dry-run -v ".#nixosConfigurations.$(hostname).config.system.build.toplevel" 2>&1 | grep -E '^evaluating file' | cut -d"'" -f2 | grep -F "$(getnixpkgspath)" | grep -E '\.nix$' | sed -E 's/^\/nix\/store\/[^\/]+\///' | sort -u
  }

  oldpath="$(getnixpkgspath)"
  getnixpkgsfiles > "$before"
  cp flake.lock flake.lock.bak
  nix flake update

  newpath="$(getnixpkgspath)"
  if ! getnixpkgsfiles > "$after"; then
    mv flake.lock.bak flake.lock
    exit 1
  fi

  mv flake.lock.bak flake.lock

  if diff "$before" "$after" &>/dev/null; then
    echo "=================================================="
    echo "No new files were added"
  else
    echo "=================================================="
    echo "File differences:"
    diff -u "$before" "$after" | ydiff -p cat

    echo "=================================================="
    echo "New files:"
    comm -2 "$before" "$after" | while read newfile; do
      bat --paging=never "$newpath/$newfile"
    done
  fi

  echo "=================================================="
  echo "Changed file contents:"
  comm -12 "$before" "$after" | while read filetodiff; do
    if ! diff "$oldpath/$filetodiff" "$newpath/$filetodiff" &>/dev/null; then
      diff -u "$oldpath/$filetodiff" "$newpath/$filetodiff" | ydiff -p cat
    fi
  done
done
