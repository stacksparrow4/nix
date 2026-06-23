{
  config,
  lib,
  pkgs,
  mkSandbox,
  ...
}:

{
  options = {
    sprrw.sec.web.enable = lib.mkEnableOption "web";
  };

  config = lib.mkIf config.sprrw.sec.web.enable {
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

      (mkSandbox {
        name = "interactsh";
        prog = "${interactsh}/bin/interactsh-client";
        sharedPaths = [
          {
            hostPath = "$HOME/.config/interactsh-client/config.yaml";
            boxPath = "/home/sprrw/.config/interactsh-client/config.yaml";
            ro = true;
            type = "file";
          }
        ];
        network = true;
      })
    ];
  };
}
