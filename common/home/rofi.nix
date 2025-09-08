{ pkgs, lib, config, ... }:

let cfg = config.sprrw.rofi; in {
  options = {
    sprrw.rofi.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    home.file.".config/rofi/config.rasi".text = ''
      @theme "${pkgs.rofi}/share/rofi/themes/Arc-Dark.rasi"
    '';

    home.packages = with pkgs; [ rofi ];
  };
}
