{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.sprrw.gui.browsers = {
    enable = lib.mkEnableOption "browsers";
  };

  config =
    let
      cfg = config.sprrw.gui.browsers;
    in
    lib.mkIf cfg.enable {
      home.packages = with pkgs; [
        brave
        firefox
        chromium
      ];
    };
}
