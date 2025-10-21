#!/usr/bin/env bash

set -e
cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null

hmPath=$(nix build .#homeConfigurations.docker.activationPackage --no-link --print-out-paths)

homeMounts=$(ls -A "$hmPath/home-files" | while read line; do
  echo -n " -v $hmPath/home-files/$line:/root/$line:ro"
done)

echo "Home mounts: $homeMounts"

docker run --rm -it -v /nix:/nix:ro -v "$hmPath":/root/.home-manager:ro $homeMounts $(docker build -q .)

