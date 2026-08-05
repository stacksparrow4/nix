# Sandboxed sage.
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
        sage = mkSandbox {
          name = "sage";
          shareCwd = true;
          prog = "${pkgs.sage}/bin/sage";
        };
      };
    };
}
