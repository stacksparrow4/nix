{ config, ... }:

{
  flake.homeModules.linux = {
    imports = with config.flake.homeModules; [
      linux-desktop-entries
      linux-rofi
      linux-sway
      linux-term
      linux-yubikey

      (
        { pkgs, config, ... }:
        {
          home.packages = with pkgs; [
            dragon-drop
            htop
            usbutils
            pciutils
            openvpn
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
