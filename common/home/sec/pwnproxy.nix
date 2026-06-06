{
  config,
  lib,
  pkgs,
  mkSandbox,
  ...
}:

{
  options = {
    sprrw.sec.pwnproxy.enable = lib.mkEnableOption "pwnproxy";
  };

  config = lib.mkIf config.sprrw.sec.pwnproxy.enable {
    home.packages =
      let
        pwnproxy = import ../../../pkgs/pwnproxy { inherit pkgs; };
      in
      [
        (mkSandbox {
          name = "pwnproxy";
          prog = "${pwnproxy}/bin/mitmproxy";
          shareCwd = true;
          sharedPaths = [
            {
              hostPath = "$HOME/.mitmproxy";
              boxPath = "/home/sprrw/.mitmproxy";
              ro = false;
              type = "dir";
            }
          ];
          network = true;
        })
      ];
  };
}
