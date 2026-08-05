{ config, ... }:

{
  # TODO: shouldn't be called graphical, should be called non-headless or something
  flake.nixosModules.graphical = {
    imports = with config.flake.nixosModules; [
      audio
      display
      fonts
      flatpak
      apps
      host-virt
    ];

    programs._1password.enable = true;
    programs._1password-gui.enable = true;

    services.gnome.gnome-keyring.enable = true;
    security.pam.services = {
      greetd.enableGnomeKeyring = true;
      swaylock.enableGnomeKeyring = true;
    };

    programs.wireshark.enable = true;

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
  };
}
