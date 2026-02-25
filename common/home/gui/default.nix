{ pkgs, lib, config, ... }:

{
  imports = [
    ./brave.nix
    ./flameshot.nix
    ./firefox.nix
  ];

  options.sprrw.gui.enable = lib.mkEnableOption "gui";

  config = lib.mkIf config.sprrw.gui.enable {
    sprrw.gui = {
      brave.enable = true;
      firefox.enable = true;
      flameshot.enable = true;
    };

    home.packages = with pkgs; [
      gimp
      inkscape
      spotify
      krita
      libreoffice
      obs-studio
      blender
      obsidian
      rofi
      freerdp
      bruno
      feh
    ];
  };
}
