#!/usr/bin/env bash

set -e
cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null

export HOME_DIR=/root

if [[ "$(uname -m)" == x86_64 ]] && [[ "$(uname -o)" == "GNU/Linux" ]] && command -v nix >/dev/null; then
  hmPath=$(nix build .#homeConfigurations.docker.activationPackage --no-link --print-out-paths --show-trace)

  homeMounts=$(echo "-v $hmPath:$HOME_DIR/.home-manager:ro"; find "$hmPath/home-files/" -type l | while read line; do
    echo -n " -v $line:$HOME_DIR/$(realpath -s --relative-to="$hmPath/home-files/" "$line"):ro"
  done)

  docker run --rm -it -v /nix:/nix:ro $homeMounts $(docker build -q .)
else
  if ! docker volume inspect nix-store &>/dev/null; then
    docker volume create nix-store || true

    docker run --rm --platform linux/amd64 -v nix-store:/nix-original nixos/nix bash -c 'cp -a /nix/* /nix-original'
  fi

  tfile=$(mktemp)

  docker run -e HOME_DIR --rm --platform linux/amd64 -i -v "$tfile":/tfile -v nix-store:/nix -v $(pwd):/pwd:ro nixos/nix bash <<"EOF"
set -e
mkdir -p ~/.config/nix
cat <<SECONDEOF > ~/.config/nix/nix.conf
extra-experimental-features = flakes nix-command
filter-syscalls = false
SECONDEOF

mkdir ~/nixos
cp -r /pwd/* ~/nixos
cd ~/nixos
hmPath=$(nix build .#homeConfigurations.docker.activationPackage --no-link --print-out-paths --show-trace)

echo "Build complete: $hmPath"

homeMounts=$(echo "-v $hmPath:$HOME_DIR/.home-manager:ro"; find "$hmPath/home-files/" -type l | while read line; do
  echo -n " -v $line:$HOME_DIR/$(realpath -s --relative-to="$hmPath/home-files/" "$line"):ro"
done)

echo "$homeMounts" > /tfile
EOF

  cat "$tfile"
fi
