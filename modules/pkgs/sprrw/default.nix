{ inputs, ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      craneLib = inputs.crane.mkLib pkgs;

      commonArgs = {
        src = craneLib.cleanCargoSource ./.;
        strictDeps = true;
      };

      cargoArtifacts = craneLib.buildDepsOnly commonArgs;
    in
    {
      packages.sprrw = craneLib.buildPackage (
        commonArgs
        // {
          inherit cargoArtifacts;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          postInstall = ''
            wrapProgram $out/bin/sprrw \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.git ]}
          '';
        }
      );
    };
}
