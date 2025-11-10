{ pkgs, lib, config, ... }:

{
  imports = [
    ./brave.nix
  ];

  options.sprrw.gui.enable = lib.mkEnableOption "gui";

  config = lib.mkIf config.sprrw.gui.enable {
    sprrw.gui.brave.enable = true;

    home.packages = with pkgs; [
      discord
      gimp
      inkscape
      spotify
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
