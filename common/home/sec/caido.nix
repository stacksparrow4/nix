{
  config,
  lib,
  pkgs,
  self',
  ...
}:

{
  options = {
    sprrw.sec.caido.enable = lib.mkEnableOption "caido";
  };

  config = lib.mkIf config.sprrw.sec.caido.enable {
    home.packages = [ self'.packages.caido ];
  };
}
