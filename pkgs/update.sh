#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell --packages nix-update

find . -maxdepth 1 -type d ! -name '.' -printf '%f\n' | while read line; do
  nix-update "$line"
done
