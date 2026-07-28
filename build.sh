#!/usr/bin/env bash

set -e
cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null

case "$(uname -s)" in
  "Darwin")
    git add .
    nix run home-manager/master -- switch --show-trace --flake .
    ;;
  "Linux")
    git add .
    nixos-rebuild switch \
      --sudo \
      --flake . \
      --option warn-dirty false \
      --show-trace \
      --print-build-logs
    nix store diff-closures $(echo /nix/var/nix/profiles/system-*-link | grep -oE '[0-9]+' | sort -n | tail -n 2 | while read line; do echo /nix/var/nix/profiles/system-$line-link; done)
    ;;
  *)
    echo "Unrecognised value for uname -s"
    exit 1
    ;;
esac

./trim-history.sh
