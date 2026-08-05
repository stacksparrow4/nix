{
  lib,
  config,
  self',
  ...
}:

{
  options = {
    sprrw.sec.windows.gcc.enable = lib.mkEnableOption "gcc";
  };

  config = lib.mkIf config.sprrw.sec.windows.gcc.enable {
    home.packages = [
      self'.packages.mingw32-gcc
      self'.packages.mingwW64-gcc
    ];
  };
}
