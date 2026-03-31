{
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [
    ./flameshot.nix
    ./obs.nix
    ./browsers.nix
  ];

  options.sprrw.gui.enable = lib.mkEnableOption "gui";

  config = lib.mkIf config.sprrw.gui.enable {
    sprrw.gui = {
      browsers.enable = true;
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
      blender
      obsidian
      rofi
      freerdp
      bruno
      feh
    ];
  };
}
