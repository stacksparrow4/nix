{ lib, flake-parts-lib, ... }:
let
  inherit (lib)
    mkOption
    types
    ;
  inherit (flake-parts-lib)
    mkTransposedPerSystemModule
    ;
in
mkTransposedPerSystemModule {
  name = "wrappers";
  option = mkOption {
    type = types.lazyAttrsOf (types.functionTo types.package);
    default = { };
  };
  file = ./wrappers.nix;
}
