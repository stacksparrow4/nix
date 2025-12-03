{ pkgs, lib, config, ... }:

{
  options.sprrw.gui.brave = {
    enable = lib.mkEnableOption "brave";
  };

  config = let
    cfg = config.sprrw.gui.brave;
  in lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      brave
    ];
  };
}
