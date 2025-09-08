{ pkgs, ... }:

with pkgs; [
  cargo
  rustc
  rust-analyzer
  rustfmt
]
