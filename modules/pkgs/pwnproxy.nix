{ inputs, ... }:

{
  perSystem =
    {
      pkgs,
      lib,
      system,
      config,
      ...
    }:
    let
      pwnproxy = inputs.pwnproxy.packages.${system}.default;
      autorize = inputs.autorize.packages.${system}.default;
    in
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        urlenc = inputs.nvim-http-client.packages.${system}.urlenc;

        pwnproxy = config.wrappers.mkSandbox {
          name = "pwnproxy";
          prog = "${pwnproxy}/bin/mitmproxy";
          shareCwd = true;
          sharedPaths = [
            {
              hostPath = "$HOME/.mitmproxy";
              boxPath = "~/.mitmproxy";
              ro = false;
              type = "dir";
            }
          ];
          network = true;
          wayland = true; # nvim copy
        };

        autorize = config.wrappers.mkSandbox {
          name = "autorize";
          prog = "${autorize}/bin/autorize";
          shareCwd = true;
          network = true;
        };
      };
    };
}
