{
  lib,
  config,
  self',
  ...
}:

{
  options = {
    sprrw.sec.windows.netexec.enable = lib.mkEnableOption "netexec";
  };

  config = lib.mkIf config.sprrw.sec.windows.netexec.enable {
    home.packages = [ self'.packages.nxc ];
  };
}
