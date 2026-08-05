{
  lib,
  config,
  self',
  ...
}:

{
  options.sprrw.gui.lmms = {
    enable = lib.mkEnableOption "lmms";
  };

  config = lib.mkIf config.sprrw.gui.lmms.enable {
    home.packages = [ self'.packages.lmms-desktop-entry ];
  };
}
