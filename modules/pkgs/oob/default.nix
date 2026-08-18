{
  perSystem =
    {
      pkgs,
      config,
      mkSandboxPkg,
      ...
    }:
    {
      packages = rec {
        oob-unboxed =
          let
            oobBin = (import ./_Cargo.nix { inherit pkgs; }).rootCrate.build;
          in
          pkgs.runCommand "oob-unboxed" { nativeBuildInputs = with pkgs; [ makeWrapper ]; } ''
            mkdir -p $out/bin
            makeWrapper ${oobBin}/bin/oob $out/bin/oob \
              --prefix PATH : ${pkgs.lib.makeBinPath [ config.packages.interactsh ]}
          '';

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
