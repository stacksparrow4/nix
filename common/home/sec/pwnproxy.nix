{
  config,
  lib,
  pkgs,
  inputs,
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
        pwnproxy = inputs.pwnproxy.packages."${pkgs.stdenv.hostPlatform.system}".default;
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
          wayland = true; # nvim copy
        })
        inputs.nvim-http-client.packages."${pkgs.stdenv.hostPlatform.system}".urlenc
      ];
  };
}
