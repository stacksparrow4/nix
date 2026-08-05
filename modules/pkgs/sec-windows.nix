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
        evil-winrm = mkSandbox {
          name = "evil-winrm";
          prog = "${pkgs.evil-winrm}/bin/evil-winrm";
          network = true;
        };

        certipy = mkSandbox {
          name = "certipy";
          prog = "${pkgs.certipy}/bin/certipy";
          shareCwd = true;
          network = true;
        };

        bloodyAD = mkSandbox {
          name = "bloodyAD";
          prog = "${pkgs.python312Packages.bloodyad}/bloodyAD";
          shareCwd = true;
          network = true;
        };

        pwsh = mkSandbox {
          name = "pwsh";
          prog = "${pkgs.powershell}/bin/pwsh";
          network = true;
        };

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
