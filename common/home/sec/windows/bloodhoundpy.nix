{
  lib,
  config,
  self',
  ...
}:

{
  options = {
    sprrw.sec.windows.bloodhoundpy.enable = lib.mkEnableOption "bloodhoundpy";
  };

  config = lib.mkIf config.sprrw.sec.windows.bloodhoundpy.enable {
    home.packages = [ self'.packages.bloodhound-ce-python ];
  };
}
