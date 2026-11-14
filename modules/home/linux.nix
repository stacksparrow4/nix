{ config, ... }:

{
  flake.modules.homeManager.linux = {
    imports = with config.flake.modules.homeManager; [
      desktop-entries
      sway

      (
        { pkgs, config, ... }:
        {
          home.packages = with pkgs; [
            dragon-drop
            usbutils
            pciutils
            libnotify
          ];

          gtk = {
            enable = true;
            theme = {
              name = "Adwaita-dark";
              package = pkgs.gnome-themes-extra;
            };
            gtk4.theme = config.gtk.theme;
          };
        }
      )
    ];
  };
}
