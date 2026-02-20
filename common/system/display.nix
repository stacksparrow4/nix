{ pkgs, lib, ... }:

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

  environment.systemPackages = with pkgs; [
    wl-clipboard
    acpilight
    acpi
    alsa-utils
    wdisplays # todo persist this with kanshi or something
    gnome-themes-extra
  ];

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    # extraOptions = [ "--unsupported-gpu" ];
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk xdg-desktop-portal-wlr ];
    config.common.default = "*";
  };

  programs = {
    thunar.enable = true;
    dconf.enable = true;
  };

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  environment.variables = {
    GTK_THEME = "Adwaita:dark";
    NIXOS_OZONE_WL = "1";       # Hint Electron apps to use Wayland
    MOZ_ENABLE_WAYLAND = "1";   # Firefox Wayland
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };
}
