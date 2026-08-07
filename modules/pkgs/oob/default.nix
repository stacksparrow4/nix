{ inputs, ... }:

{
  perSystem =
    {
      pkgs,
      config,
      mkSandboxPkg,
      ...
    }:
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
      packages = rec {
        oob-unboxed = craneLib.buildPackage (
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

        oob = mkSandboxPkg {
          name = "oob";
          prog = "${oob-unboxed}/bin/oob";
          sharedPaths = [
            {
              hostPath = "$HOME/.config/interactsh-client/config.yaml";
              boxPath = "/home/sprrw/.config/interactsh-client/config.yaml";
              ro = true;
              type = "file";
            }
          ];
          network = true;
        };
      };
    };
}
