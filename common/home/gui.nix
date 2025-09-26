{ pkgs, lib, config, ... }:

{
  options.sprrw.gui.enable = lib.mkEnableOption "gui";

  config = lib.mkIf config.sprrw.gui.enable {
    home.packages = with pkgs; [
      discord
      gimp
      inkscape
      spotify
      brave
      krita
      libreoffice
      obs-studio
      blender
      binaryninja-free
      ghidra
      obsidian
      rofi
      flameshot
      freerdp
      bruno
      wireshark
    ];
  };
}
