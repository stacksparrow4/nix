#!/usr/bin/env bash

set -e
cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null

FORCE_DOCKER_BUILD=0

DOCKER_IMAGE=ubuntu:latest

if [[ "$FORCE_DOCKER_BUILD" != 1 ]] && [[ "$(uname -m)" == x86_64 ]] && [[ "$(uname -o)" == "GNU/Linux" ]] && command -v nix >/dev/null; then
  git add .

  dockerinitpath=$(nix build .#dockerinit --no-link --print-out-paths --show-trace)

  docker run --rm -it -v /nix:/nix:ro -v "$dockerinitpath:/.entrypoint.sh:ro" "$DOCKER_IMAGE" /.entrypoint.sh
else
  if ! docker volume inspect nix-store &>/dev/null; then
    docker volume create nix-store || true

    docker run --rm --platform linux/amd64 -v nix-store:/nix-original nixos/nix bash -c 'cp -a /nix/* /nix-original'
  fi

  docker run --rm --platform linux/amd64 -i -v nix-store:/nix -v $(pwd):/pwd:ro nixos/nix bash <<"EOF"
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
fi
