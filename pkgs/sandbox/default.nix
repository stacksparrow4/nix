# The Rust source now lives in ../rust, as a workspace member sharing the command
# bridge with pi-boxed.
{
  pkgs ? import <nixpkgs-unstable> { },
  crane,
}:

(import ../rust { inherit pkgs crane; }).sandbox
