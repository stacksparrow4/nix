#!/bin/sh

docker run --rm -it -v /nix:/nix:ro -v /etc/profiles/per-user/$USER:/etc/profiles/per-user/root:ro -v $HOME/.config:/root/.config:ro $(docker build -q .)
