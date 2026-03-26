{
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [
    ./flameshot.nix
    ./firefox.nix
    ./obs.nix
  ];

  options.sprrw.gui.enable = lib.mkEnableOption "gui";

  config = lib.mkIf config.sprrw.gui.enable {
    sprrw.gui = {
      firefox.enable = true;
      flameshot.enable = true;
      obs.enable = true;
    };

    home.packages = with pkgs; [
      gimp
      inkscape
      spotify
      krita
      kdePackages.kdenlive
      vlc
      libreoffice
      blender
      obsidian
      rofi
      freerdp
      bruno
      feh
    ];
  };
}
