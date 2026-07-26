{
  pkgs ? import <nixpkgs-unstable> { },
  models, # List of { name, path } attrsets, where path is a GGUF file
  context,
}:

let
  modelsDir = pkgs.linkFarm "llama-models" (
    map (
      { name, path }:
      {
        name = "${name}.gguf";
        inherit path;
      }
    ) models
  );

  llama-server = pkgs.rustPlatform.buildRustPackage {
    pname = "llama-server";
    version = "0.1.0";

    src = ./.;

    cargoHash = "sha256-Y3XeqwUpbbD6hK2Wxh8O6vL5m2gtBvg2QmxzVGAetPk=";
  };
in
pkgs.writeShellApplication {
  name = "llama-server";
  runtimeInputs = [ pkgs.socat ];
  text = ''
    ${llama-server}/bin/llama-server ${modelsDir} ${toString context} "$@"
  '';
}
