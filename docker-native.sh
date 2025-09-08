#!/usr/bin/env bash

buildpath="$(nix build --show-trace --no-link --print-out-paths .#docker)"
docker load < "$buildpath"
