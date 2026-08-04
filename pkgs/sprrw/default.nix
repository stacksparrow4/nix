{
  pkgs,
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

    nativeBuildInputs = [ pkgs.makeWrapper ];

    postInstall = ''
      wrapProgram $out/bin/sprrw \
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.git ]}
    '';
  }
)
