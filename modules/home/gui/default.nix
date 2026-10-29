{ config, moduleWithSystem, ... }:

{
  flake.modules.homeManager.gui = {
    imports = with config.flake.modules.homeManager; [
      browsers

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
            pkgsUnstable.flameshot
            self'.packages.wlfreerdp
            self'.packages.emoji-picker
            obs-studio
          ];
        }
      ))
    ];
  };
}
