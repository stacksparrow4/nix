#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell --packages nix-update

for pkg in pi; do
  nix-update "$pkg"
done
