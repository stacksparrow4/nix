{
  perSystem =
    {
      pkgs,
      lib,
      config,
      mkSandbox,
      ...
    }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        nxc = mkSandbox {
          name = "nxc";
          sharedPaths = [
            {
              hostPath = "$HOME/.nxc";
              boxPath = "/home/sprrw/.nxc";
              ro = false;
              type = "dir";
            }
          ];
          shareCwd = true;
          network = true;
          prog = "${config.packages.netexec}/bin/nxc";
        };

        bloodhound-ce-python = mkSandbox {
          name = "bloodhound-ce";
          shareCwd = true;
          network = true;
          prog = "${config.packages.bloodhound-ce}/bin/bloodhound-ce-python";
        };
      };
    };
}
