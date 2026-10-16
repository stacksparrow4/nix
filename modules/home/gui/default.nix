{ config, moduleWithSystem, ... }:

{
  flake.homeModules.gui = {
    imports = with config.flake.homeModules; [
      browsers
      emoji-picker

      (moduleWithSystem (
        { self', pkgsUnstable, ... }:
        { pkgs, ... }:
        {
          home.packages = with pkgs; [
            gimp
            inkscape
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
