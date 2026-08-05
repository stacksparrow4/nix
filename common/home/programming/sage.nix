{
  config,
  lib,
  self',
  ...
}:

{
  options = {
    sprrw.programming.sage.enable = lib.mkEnableOption "sage";
  };

  config = lib.mkIf config.sprrw.programming.sage.enable {
    home.packages = [ self'.packages.sage ];
  };
}
