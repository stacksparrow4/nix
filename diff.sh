#!/bin/sh

set -e

nixpkgspathbefore=$(nix eval --raw --impure --expr '(builtins.getFlake "path://'"$(pwd)"'").inputs.nixpkgs.outPath')
nixpkgsunstablepathbefore=$(nix eval --raw --impure --expr '(builtins.getFlake "path://'"$(pwd)"'").inputs.nixpkgs-unstable.outPath')
filelistbefore=$(nix build --dry-run -v ".#nixosConfigurations.$(hostname).config.system.build.toplevel" 2>&1 | grep -E '^evaluating file' | cut -d"'" -f2 | grep -E '\.nix$')
cp flake.lock flake.lock.bak
nix flake update
nixpkgspathafter=$(nix eval --raw --impure --expr '(builtins.getFlake "path://'"$(pwd)"'").inputs.nixpkgs.outPath')
nixpkgsunstablepathafter=$(nix eval --raw --impure --expr '(builtins.getFlake "path://'"$(pwd)"'").inputs.nixpkgs-unstable.outPath')
filelistafter=$(nix build --dry-run -v ".#nixosConfigurations.$(hostname).config.system.build.toplevel" 2>&1 | grep -E '^evaluating file' | cut -d"'" -f2 | grep -E '\.nix$')
mv flake.lock.bak flake.lock

checkchanges() {
  echo "=================================================="
  echo "=================================================="
  echo "CHECKING FOR CHANGES FOR INPUT $1:"

  before=$(echo "$filelistbefore" | grep -F "$2" | sed -E 's/^\/nix\/store\/[^\/]+\///' | sort -u)
  after=$(echo "$filelistafter" | grep -F "$3" | sed -E 's/^\/nix\/store\/[^\/]+\///' | sort -u)

  if diff <(echo "$before") <(echo "$after") &>/dev/null; then
    echo "=================================================="
    echo "No new files were added"
  else
    echo "=================================================="
    echo "File differences:"
    diff -u <(echo "$before") <(echo "$after") | ydiff -p cat

    echo "=================================================="
    echo "New files:"
    comm -13 <(echo "$before") <(echo "$after") | while read newfile; do
      bat --paging=never "$3/$newfile"
    done
  fi

  echo "=================================================="
  echo "Changed file contents:"
  comm -12 <(echo "$before") <(echo "$after") | while read filetodiff; do
    if ! diff "$2/$filetodiff" "$3/$filetodiff" &>/dev/null; then
      diff -u "$2/$filetodiff" "$3/$filetodiff" | ydiff -p cat
    fi
  done
}

checkchanges nixpkgs "$nixpkgspathbefore" "$nixpkgspathafter"
checkchanges nixpkgs-unstable "$nixpkgsunstablepathbefore" "$nixpkgsunstablepathafter"
