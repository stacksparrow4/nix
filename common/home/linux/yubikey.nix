{ pkgs, lib, config, ... }:

{
  options = {
    sprrw.linux.yubikey.enable = lib.mkEnableOption "yubikey";
  };

  config = lib.mkIf config.sprrw.linux.yubikey.enable {
    home.packages = with pkgs; [ yubioath-flutter ];
  };
}
