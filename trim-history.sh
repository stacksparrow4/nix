#!/usr/bin/env bash

if [[ "$(uname -s)" = "Darwin" ]]; then
  echo "Trimming home manager profile..."
  nix-env --delete-generations +2 --profile ~/.local/state/nix/profiles/home-manager
else
  PROFILES=(/nix/var/nix/profiles/system ~/.local/state/nix/profiles/home-manager ~/.local/state/nix/profiles/profile)

  for p in ${PROFILES[@]}; do
    echo "Trimming profiles for $p"
    sudo nix-env --delete-generations +2 --profile "$p"
  done
fi
