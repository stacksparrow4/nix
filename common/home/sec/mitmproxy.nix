{
  config,
  lib,
  pkgs,
  mkSandbox,
  ...
}:

{
  options = {
    sprrw.sec.mitmproxy.enable = lib.mkEnableOption "mitmproxy";
  };

  config = lib.mkIf config.sprrw.sec.mitmproxy.enable {
    home.packages = with pkgs; [
      (mkSandbox {
        name = "mitmproxy";
        prog = "${mitmproxy}/bin/mitmproxy";
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
