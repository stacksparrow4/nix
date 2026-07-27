{
  pkgs ? import <nixpkgs-unstable> { },
  crane,
}:

let
  craneLib = crane.mkLib pkgs;

  interactsh = pkgs.runCommand "interactsh" { } ''
    mkdir -p $out/bin
    ln -s ${import ../interactsh { inherit pkgs; }}/bin/interactsh-client $out/bin/interactsh
  '';

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

    nativeBuildInputs = [ pkgs.makeWrapper ];

    postInstall = ''
      wrapProgram $out/bin/oob \
        --prefix PATH : ${pkgs.lib.makeBinPath [ interactsh ]}
    '';
  }
)
