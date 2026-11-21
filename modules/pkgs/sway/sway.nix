{
  perSystem =
    {
      pkgs,
      ...
    }:
    {
      packages = {
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
