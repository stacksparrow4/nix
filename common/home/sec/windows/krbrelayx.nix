{
  lib,
  config,
  self',
  ...
}:

{
  options = {
    sprrw.sec.windows.krbrelayx.enable = lib.mkEnableOption "krbrelayx";
  };

  config = lib.mkIf config.sprrw.sec.windows.krbrelayx.enable {
    home.packages = [ self'.packages.krbrelayx ];
  };
}
