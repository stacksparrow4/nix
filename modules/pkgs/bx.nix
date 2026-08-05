{
  perSystem =
    {
      pkgs,
      lib,
      mkSandbox,
      ...
    }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        bx = mkSandbox {
          name = "bx";
          sharedPaths = [
            {
              hostPath = "$HOME/.config/brave-search";
              boxPath = "/home/sprrw/.config/brave-search";
              ro = false;
              type = "dir";
            }
          ];
          network = true;
          prog = "${pkgs.brave-search-cli}/bin/bx";
        };
      };
    };
}
