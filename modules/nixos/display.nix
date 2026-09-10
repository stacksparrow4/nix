{ moduleWithSystem, ... }:

{
  flake.nixosModules.display = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      security.polkit.enable = true;

      environment.systemPackages = with pkgs; [
        wl-clipboard
        acpilight
        acpi
        alsa-utils
        wdisplays
        gnome-themes-extra
      ];

      programs.sway = {
        enable = true;
        wrapperFeatures.gtk = true;
        extraOptions = [ "--unsupported-gpu" ];
      };

      xdg.portal = {
        enable = true;
        wlr = {
          enable = true;

          settings.screencast = {
            chooser_type = "dmenu";
            chooser_cmd = "${self'.packages.portal-chooser}/bin/portal-chooser";
          };
        };
        extraPortals = with pkgs; [
          xdg-desktop-portal-gtk
          xdg-desktop-portal-wlr
          xdg-desktop-portal-termfilechooser
        ];

        config = {
          common = {
            default = [ "gtk" ];
            "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
            "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
            "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
          };
          sway."org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
        };
      };

      systemd.user.services.xdg-desktop-portal-termfilechooser.serviceConfig.ExecStart =
        let
          termfilechooserConfig = pkgs.writeText "termfilechooser-config" ''
            [filechooser]
            cmd=${self'.packages.yazi-file-picker}/bin/yazi-file-picker
            default_dir=$HOME
            open_mode=suggested
            save_mode=suggested
          '';
        in
        [
          ""
          "${pkgs.xdg-desktop-portal-termfilechooser}/libexec/xdg-desktop-portal-termfilechooser -c ${termfilechooserConfig}"
        ];

      programs.dconf.enable = true;

      services.greetd = {
        enable = true;
        settings = {
          default_session = {
            command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd sway";
            user = "greeter";
          };
        };
        useTextGreeter = true;
      };

      environment.variables = {
        GTK_THEME = "Adwaita:dark";
        NIXOS_OZONE_WL = "1"; # Hint Electron apps to use Wayland
        MOZ_ENABLE_WAYLAND = "1"; # Firefox Wayland
        QT_QPA_PLATFORM = "wayland";
        SDL_VIDEODRIVER = "wayland";
        _JAVA_AWT_WM_NONREPARENTING = "1";
      };
    }
  );
}
