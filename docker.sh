#!/usr/bin/env bash

set -e
cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null

hmPath=$(nix build .#homeConfigurations.docker.activationPackage --no-link --print-out-paths)

homeMounts=$(find "$hmPath/home-files/" -type l | while read line; do
echo -n " -v $line:/root/$(realpath -s --relative-to="$hmPath/home-files/" "$line"):ro"
done)

echo "$homeMounts"

docker run --rm -it -v /nix:/nix:ro -v "$hmPath":/root/.home-manager:ro $homeMounts $(docker build -q .)
