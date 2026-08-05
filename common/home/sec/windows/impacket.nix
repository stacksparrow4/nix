{
  lib,
  config,
  self',
  ...
}:

{
  options = {
    sprrw.sec.windows.impacket.enable = lib.mkEnableOption "impacket";
  };

  config = lib.mkIf config.sprrw.sec.windows.impacket.enable {
    home.packages = [ self'.packages.impacket-sandboxed ];
  };
}
