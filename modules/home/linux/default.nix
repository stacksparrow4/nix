{ config, ... }:

{
  flake.modules.homeManager.linux = {
    imports = with config.flake.modules.homeManager; [
      desktop-entries
      rofi
      sway
      linux-tools

      (
        { pkgs, config, ... }:
        {
          home.packages = with pkgs; [
            dragon-drop
            htop
            usbutils
            pciutils
            openvpn
            libnotify
          ];

          # 1password stuff
          services.gnome-keyring = {
            enable = true;
            components = [ "secrets" ];
          };

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
