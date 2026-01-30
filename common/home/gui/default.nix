{ pkgs, lib, config, ... }:

{
  imports = [
    ./brave.nix
    ./firefox.nix
  ];

  options.sprrw.gui.enable = lib.mkEnableOption "gui";

  config = lib.mkIf config.sprrw.gui.enable {
    sprrw.gui.brave.enable = true;
    sprrw.gui.firefox.enable = true;

    home.packages = with pkgs; [
      discord
      gimp
      inkscape
      spotify
      krita
      libreoffice
      obs-studio
      blender
      obsidian
      rofi
      flameshot
      freerdp
      bruno
      feh
    ];
  };
}
