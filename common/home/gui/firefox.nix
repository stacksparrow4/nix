{ pkgs, lib, config, ... }:

{
  options.sprrw.gui.firefox = {
    enable = lib.mkEnableOption "firefox";
  };

  config = let
    cfg = config.sprrw.gui.firefox;
  in lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      firefox
    ];
  };
}
