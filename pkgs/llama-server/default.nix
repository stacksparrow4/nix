{
  pkgs ? import <nixpkgs-unstable> { },
  crane,
  models, # List of { name, path } attrsets, where path is a GGUF file
  context,
}:

let
  craneLib = crane.mkLib pkgs;

  modelsDir = pkgs.linkFarm "llama-models" (
    map (
      { name, path }:
      {
        name = "${name}.gguf";
        inherit path;
      }
    ) models
  );

  commonArgs = {
    src = craneLib.cleanCargoSource ./.;
    strictDeps = true;
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;

  llama-server = craneLib.buildPackage (
    commonArgs
    // {
      inherit cargoArtifacts;
    }
  );
in
pkgs.writeShellApplication {
  name = "llama-server";
  runtimeInputs = [ pkgs.socat ];
  text = ''
    ${llama-server}/bin/llama-server ${modelsDir} ${toString context} "$@"
  '';
}
