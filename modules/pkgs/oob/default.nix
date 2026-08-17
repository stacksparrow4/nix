{
  perSystem =
    {
      pkgs,
      config,
      mkSandboxPkg,
      ...
    }:
    let
      interactsh-client = pkgs.runCommand "interactsh" { } ''
        mkdir -p $out/bin
        ln -s ${config.packages.interactsh}/bin/interactsh-client $out/bin/interactsh
      '';
    in
    {
      packages = rec {
        oob-unboxed =
          let
            oobBin = (import ./_Cargo.nix { inherit pkgs; }).rootCrate.build;
          in
          pkgs.runCommand "oob-unboxed" { nativeBuildInputs = with pkgs; [ makeBinaryWrapper ]; } ''
            mkdir -p $out/bin
            makeWrapper ${oobBin}/bin/oob $out/bin/oob \
              --prefix PATH : ${pkgs.lib.makeBinPath [ interactsh-client ]}
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
