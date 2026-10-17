{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        sway = pkgs.sway.override {
          sway-unwrapped = pkgs.sway-unwrapped.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [
              ./sway-check-constraint-region.patch
            ];
          });
        };
      };
    };
}
