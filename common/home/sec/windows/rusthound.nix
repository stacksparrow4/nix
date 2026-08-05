{
  lib,
  config,
  self',
  ...
}:

{
  options = {
    sprrw.sec.windows.rusthound.enable = lib.mkEnableOption "rusthound";
  };

  config = lib.mkIf config.sprrw.sec.windows.rusthound.enable {
    home.packages = [ self'.packages.rusthound-ce ];
  };
}
