#!/usr/bin/env bash

set -e
cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null

DOCKER_IMAGE=ubuntu:latest
NIX_IMAGE=nixos/nix@sha256:04abdb9c74e0bd20913ca84e4704419af31e49e901cd57253ed8f9762def28fd

if ! docker volume inspect nix-store &>/dev/null; then
  docker volume create nix-store || true

  docker run --rm --platform linux/amd64 -v nix-store:/nix-original "$NIX_IMAGE" bash -c 'cp -a /nix/* /nix-original'
fi

docker run --rm --platform linux/amd64 -i -v nix-store:/nix -v $(pwd):/pwd:ro "$NIX_IMAGE" bash <<"EOF"
set -e
mkdir -p ~/.config/nix
cat <<SECONDEOF > ~/.config/nix/nix.conf
extra-experimental-features = flakes nix-command
filter-syscalls = false
SECONDEOF

mkdir ~/nixos
cp -r /pwd/* ~/nixos
cd ~/nixos
dockerinitpath=$(nix build .#dockerinit --no-link --print-out-paths --show-trace)

echo "Build complete: $dockerinitpath"

rm -f /nix/.entrypoint.sh
ln -s "$dockerinitpath" /nix/.entrypoint.sh
EOF

docker run --platform linux/amd64 --rm -it -v nix-store:/nix:ro "$DOCKER_IMAGE" /nix/.entrypoint.sh
