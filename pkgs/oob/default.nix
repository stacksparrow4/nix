{
  pkgs ? import <nixpkgs-unstable> { },
}:

let
  interactsh = pkgs.runCommand "interactsh" { } ''
    mkdir -p $out/bin
    ln -s ${import ../interactsh { inherit pkgs; }}/bin/interactsh-client $out/bin/interactsh
  '';
in
pkgs.rustPlatform.buildRustPackage (finalAttrs: {
  pname = "oob";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/oob \
      --prefix PATH : ${pkgs.lib.makeBinPath [ interactsh ]}
  '';

  cargoHash = "sha256-yZ+0OJ/Em1hGflTTPu2yVTnbxj8tV9woBkjA+DN5PB0=";
})
