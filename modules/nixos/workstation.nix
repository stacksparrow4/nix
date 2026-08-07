{ config, ... }:

{
  flake.nixosModules.workstation = {
    imports = with config.flake.nixosModules; [
      audio
      display
      fonts
      flatpak
      apps
      workstation-virt
    ];

    programs._1password.enable = true;
    programs._1password-gui.enable = true;

    services.gnome.gnome-keyring.enable = true;
    security.pam.services = {
      greetd.enableGnomeKeyring = true;
      swaylock.enableGnomeKeyring = true;
    };

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
  };
}
