{
  lib,
  config,
  self',
  ...
}:

{
  options.sprrw.gui.emoji-picker = {
    enable = lib.mkEnableOption "emoji-picker";
  };

  config = lib.mkIf config.sprrw.gui.emoji-picker.enable {
    home.packages = [ self'.packages.emoji-picker ];
  };
}
