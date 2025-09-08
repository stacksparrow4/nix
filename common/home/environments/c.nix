{ pkgs, ... }:

with pkgs; [
  gcc
  gnumake
  clang-tools
  cmake
  cmake-language-server
]
