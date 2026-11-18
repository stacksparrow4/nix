{ config, ... }:

{
  flake.modules.nixos.workstation = {
    imports = with config.flake.modules.nixos; [
      audio
      display
      fonts
      flatpak
      apps
    ];

    programs._1password.enable = true;
    programs._1password-gui.enable = true;

    services.gnome.gnome-keyring.enable = true;
    security.pam.services.greetd.enableGnomeKeyring = true;

    boot.loader.systemd-boot.enable = true;
    boot.loader.systemd-boot.configurationLimit = 3;
    boot.loader.efi.canTouchEfiVariables = true;
  };
}
