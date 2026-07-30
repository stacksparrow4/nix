{
  pkgs ? import <nixpkgs-unstable> { },
  crane,
}:

let
  craneLib = crane.mkLib pkgs;

  commonArgs = {
    src = craneLib.cleanCargoSource ./.;
    strictDeps = true;
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;
in
craneLib.buildPackage (
  commonArgs
  // {
    inherit cargoArtifacts;
  }
)
