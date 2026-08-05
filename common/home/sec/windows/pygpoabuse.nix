{
  lib,
  config,
  self',
  ...
}:

{
  options = {
    sprrw.sec.windows.pygpoabuse.enable = lib.mkEnableOption "pygpoabuse";
  };

  config = lib.mkIf config.sprrw.sec.windows.pygpoabuse.enable {
    home.packages = [ self'.packages.pygpoabuse ];
  };
}
