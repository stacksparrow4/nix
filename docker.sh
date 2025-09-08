#!/usr/bin/env bash

set -e
cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null

git add .

if [[ -z "$(docker ps -q --filter 'name=nixos-builder')" ]]; then
  if [[ -z "$(docker ps -a -q --filter 'name=nixos-builder')" ]]; then
    docker run -d --platform linux/amd64 --name nixos-builder -i -v $(pwd):/pwd nixos/nix bash -c 'sleep infinity'
    docker exec -i nixos-builder bash <<"EOF"
mkdir -p ~/.config/nix
cat <<SECONDEOF > ~/.config/nix/nix.conf
extra-experimental-features = flakes nix-command
filter-syscalls = false
SECONDEOF
EOF
  else
    docker start nixos-builder
  fi
fi

docker exec -i nixos-builder bash <<"EOF"
set -e
rm -rf ~/nixos
mkdir ~/nixos
cp -r /pwd/* ~/nixos
cd ~/nixos
buildpath="$(nix build --show-trace --no-link --print-out-paths .#docker)"
cp "$buildpath" /pwd/build.docker
EOF

docker load < build.docker
rm -f build.docker
