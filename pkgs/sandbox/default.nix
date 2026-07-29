{
  pkgs ? import <nixpkgs-unstable> { },
  crane,
}:

(import ../rust { inherit pkgs crane; }).sandbox
