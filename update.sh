#!/usr/bin/env bash

set -e
cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null

nix flake update
./build.sh

# TODO: fix this for home manager only systems
nix store diff-closures $(echo /nix/var/nix/profiles/system-*-link | grep -oE '[0-9]+' | sort -n | tail -n 2 | while read line; do echo /nix/var/nix/profiles/system-$line-link; done)
