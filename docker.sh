#!/usr/bin/env bash

set -e
cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null

HOME_DIR=/root

# TODO: build this cross platform using docker if we aren't on a NixOS system

hmPath=$(nix build .#homeConfigurations.docker.activationPackage --no-link --print-out-paths)

homeMounts=$(find "$hmPath/home-files/" -type l | while read line; do
echo -n " -v $line:$HOME_DIR/$(realpath -s --relative-to="$hmPath/home-files/" "$line"):ro"
done)

docker run --rm -it -v /nix:/nix:ro -v "$hmPath":"$HOME_DIR/.home-manager":ro $homeMounts $(docker build -q .)
