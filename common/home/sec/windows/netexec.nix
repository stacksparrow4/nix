{
  lib,
  config,
  mkSandbox,
  self',
  ...
}:

{
  options = {
    sprrw.sec.windows.netexec.enable = lib.mkEnableOption "netexec";
  };

  config = lib.mkIf config.sprrw.sec.windows.netexec.enable {
    home.packages = [
      (mkSandbox {
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
        prog = "${self'.packages.netexec}/bin/nxc";
      })
    ];
  };
}
