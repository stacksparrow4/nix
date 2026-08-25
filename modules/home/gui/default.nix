{ config, moduleWithSystem, ... }:

{
  flake.homeModules.gui = {
    imports = with config.flake.homeModules; [
      gui-browsers
      gui-emoji-picker

      (moduleWithSystem (
        { self', pkgsUnstable, ... }:
        { pkgs, ... }:
        {
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
            pkgsUnstable.flameshot
            self'.packages.wlfreerdp
            obs-studio
          ];
        }
      ))
    ];
  };
}
