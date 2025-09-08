#!/usr/bin/env bash

set -e
cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null

PROFILES=(/nix/var/nix/profiles/system ~/.local/state/nix/profiles/home-manager ~/.local/state/nix/profiles/profile)

for p in ${PROFILES[@]}; do
  sudo nix profile wipe-history --profile "$p"
done

sudo nix-collect-garbage
