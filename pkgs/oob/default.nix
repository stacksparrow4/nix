{
  pkgs ? import <nixpkgs-unstable> { },
}:

pkgs.rustPlatform.buildRustPackage (finalAttrs: {
  pname = "oob";
  version = "0.1.0";

  src = ./.;

  buildInputs = [
    (pkgs.runCommand "interactsh" { } ''
      mkdir -p $out/bin
      ln -s ${import ../interactsh { inherit pkgs; }}/bin/interactsh-client $out/bin/interactsh
    '')
  ];

  cargoHash = "sha256-yZ+0OJ/Em1hGflTTPu2yVTnbxj8tV9woBkjA+DN5PB0=";
})
