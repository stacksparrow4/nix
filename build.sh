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
    if [[ "$(whoami)" == "kali" ]]; then
      nix run home-manager/master -- switch --show-trace --flake . -b bak
    else
      sudo nixos-rebuild switch --flake . --show-trace
    fi
    ;;
  *)
    echo "Unrecognised value for uname -s"
    exit 1
    ;;
esac

./trim-history.sh
