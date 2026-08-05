{
  pkgs,
  pkgs-unstable,
  lib,
  config,
  self',
  ...
}:

{
  imports = [
    ./obs.nix
    ./browsers.nix
    ./emoji-picker.nix
    ./signal.nix
    ./lmms.nix
  ];

  options.sprrw.gui.enable = lib.mkEnableOption "gui";

  config = lib.mkIf config.sprrw.gui.enable {
    sprrw.gui = {
      browsers.enable = true;
      obs.enable = true;
      emoji-picker.enable = true;
    };

    home.packages = with pkgs; [
      gimp
      inkscape
      spotify
      krita
      kdePackages.kdenlive
      kdePackages.filelight
      vlc
      blender
      rofi
      pkgs-unstable.flameshot
      self'.packages.wlfreerdp
    ];
  };
}
