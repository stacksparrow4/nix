{ inputs, ... }:

{
  perSystem =
    {
      pkgs,
      lib,
      system,
      self',
      ...
    }:
    let
      pwnproxy = inputs.pwnproxy.packages.${system}.default;
      autorize = inputs.autorize.packages.${system}.default;
    in
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        urlenc = inputs.nvim-http-client.packages.${system}.urlenc;

        pwnproxy = self'.wrappers.mkSandbox {
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
            {
              hostPath = "$HOME/.config/pwnproxy";
              boxPath = "~/.pwnproxy";
              ro = true;
              type = "dir";
            }
          ];
          network = true;
          wayland = true; # nvim copy
        };

        autorize = self'.wrappers.mkSandbox {
          name = "autorize";
          prog = "${autorize}/bin/autorize";
          shareCwd = true;
          network = true;
        };
      };
    };
}
