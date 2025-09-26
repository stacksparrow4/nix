{ pkgs, lib, config, ... }:

{
  options = {
    sprrw.linux.rofi.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf config.sprrw.linux.rofi.enable {
    home.file.".config/rofi/config.rasi".text = ''
      @theme "${pkgs.rofi}/share/rofi/themes/Arc-Dark.rasi"
    '';

    home.packages = with pkgs; [ rofi ];
  };
}
