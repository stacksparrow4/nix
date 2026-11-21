{
  perSystem =
    {
      pkgs,
      self',
      ...
    }:
    {
      packages = rec {
        oob-unboxed =
          let
            oobBin = (pkgs.callPackage ./_Cargo.nix { }).rootCrate.build;
          in
          pkgs.runCommand "oob-unboxed"
            {
              nativeBuildInputs = with pkgs; [ makeWrapper ];
              meta.mainProgram = "oob";
            }
            ''
              mkdir -p $out/bin
              makeWrapper ${oobBin}/bin/oob $out/bin/oob \
                --prefix PATH : ${pkgs.lib.makeBinPath [ self'.packages.interactsh-unboxed ]}
            '';

        oob = self'.wrappers.mkSandbox {
          name = "oob";
          prog = "${oob-unboxed}/bin/oob";
          sharedPaths = [
            {
              hostPath = "$HOME/.config/interactsh-client/config.yaml";
              boxPath = "~/.config/interactsh-client/config.yaml";
              ro = true;
              type = "file";
            }
          ];
          network = true;
        };
      };
    };
}
