{
  config,
  lib,
  pkgs,
  self',
  ...
}:

{
  options = {
    sprrw.sec.jwttool.enable = lib.mkEnableOption "jwttool";
  };

  config = lib.mkIf config.sprrw.sec.jwttool.enable {
    home.packages = [ self'.packages.jwt-tool ];
  };
}
