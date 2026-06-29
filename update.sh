#!/usr/bin/env bash

set -e
cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null

(cd ./pkgs && ./update.sh)

nix flake update
