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
        wlfreerdp = mkSandbox {
          name = "wlfreerdp";
          wayland = true;
          network = true;
          prog = "${pkgs.freerdp}/bin/wlfreerdp";
        };
      };
    };
}
