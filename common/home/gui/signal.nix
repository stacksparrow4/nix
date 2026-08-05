{
  lib,
  config,
  self',
  ...
}:

{
  options.sprrw.gui.signal = {
    enable = lib.mkEnableOption "signal";
  };

  config = lib.mkIf config.sprrw.gui.signal.enable {
    home.packages = [ self'.packages.signal-desktop-entry ];
  };
}
