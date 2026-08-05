{ inputs, ... }:

{
  perSystem =
    { pkgs, config, ... }:
    let
      craneLib = inputs.crane.mkLib pkgs;

      interactsh-client = pkgs.runCommand "interactsh" { } ''
        mkdir -p $out/bin
        ln -s ${config.packages.interactsh}/bin/interactsh-client $out/bin/interactsh
      '';

      commonArgs = {
        src = craneLib.cleanCargoSource ./.;
        strictDeps = true;
      };

      cargoArtifacts = craneLib.buildDepsOnly commonArgs;
    in
    {
      packages.oob = craneLib.buildPackage (
        commonArgs
        // {
          inherit cargoArtifacts;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          postInstall = ''
            wrapProgram $out/bin/oob \
              --prefix PATH : ${pkgs.lib.makeBinPath [ interactsh-client ]}
          '';
        }
      );
    };
}
