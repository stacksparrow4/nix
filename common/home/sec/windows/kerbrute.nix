{
  lib,
  config,
  self',
  ...
}:

{
  options = {
    sprrw.sec.windows.kerbrute.enable = lib.mkEnableOption "kerbrute";
  };

  config = lib.mkIf config.sprrw.sec.windows.kerbrute.enable {
    home.packages = [ self'.packages.kerbrute ];
  };
}
