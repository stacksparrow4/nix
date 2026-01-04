{ pkgs, lib, config, ... }:

{
  # https://github.com/kachick/dotfiles/blob/16832e2dbf0c5debe3c14bd0e1fd4e46c667a2b0/nixos/hardware.nix#L19
  services.udev = {
    enable = true;
    extraHwdb = lib.mkBefore ''
      evdev:input:b*v*p*
        KEYBOARD_KEY_3a=esc
        KEYBOARD_KEY_58=esc
        KEYBOARD_KEY_70039=esc
    '';
  };

  services = {
    xserver = {
      enable = true;
      # Keyboard
      xkb = {
        layout = "au";
        variant = "";
      };
      # i3
      windowManager.i3 = {
        enable = true;
        extraPackages = with pkgs; [
          i3blocks
        ];
      };
      # Desktop
      desktopManager = {
        xterm.enable = false;
        xfce = {
          enable = true;
          noDesktop = true;
          enableXfwm = false;
        };
        wallpaper = {
          combineScreens = true;
          mode = "fill";
        };
      };
      # Display Manager
      displayManager = {
        lightdm = {
          enable = true;
          # Greeter (AKA login screen)
          greeters = {
            gtk = {
              enable = true;
              extraConfig = ''
                font-name = ${config.sprrw.font.mainFontName}
              '';
              theme = {
                name = "Arc-Dark";
                package = pkgs.arc-theme;
              };
            };
          };
        };
      };
    };
    displayManager.defaultSession = "xfce+i3";
    # GVFS is apparently to do with trash can
    gvfs.enable = true;
  };

  programs = {
    thunar.enable = true;
    dconf.enable = true;
  };

  environment.variables = {
    GTK_THEME = "Adwaita-dark";
  };

  environment.systemPackages = with pkgs; [
    xbacklight
    acpi
    alsa-utils
  ];
}
