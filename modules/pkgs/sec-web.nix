{
  perSystem =
    {
      pkgs,
      lib,
      config,
      mkSandbox,
      ...
    }:
    let
      interactshConfig = [
        {
          hostPath = "$HOME/.config/interactsh-client/config.yaml";
          boxPath = "/home/sprrw/.config/interactsh-client/config.yaml";
          ro = true;
          type = "file";
        }
      ];
    in
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        interactsh-boxed = mkSandbox {
          name = "interactsh";
          prog = "${config.packages.interactsh}/bin/interactsh-client";
          sharedPaths = interactshConfig;
          network = true;
        };

        oob-boxed = mkSandbox {
          name = "oob";
          prog = "${config.packages.oob}/bin/oob";
          sharedPaths = interactshConfig;
          network = true;
        };
      };
    };
}
