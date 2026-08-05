{ config, ... }:

# Everything that used to sit behind `lib.mkIf (!config.sprrw.headless)`.
# Headless hosts simply don't import this.
{
  flake.nixosModules.graphical = {
    imports = with config.flake.nixosModules; [
      audio
      display-graphical
      fonts
      flatpak
      apps
      virt-graphical
    ];

    programs._1password.enable = true;
    programs._1password-gui.enable = true;

    services.gnome.gnome-keyring.enable = true;
    security.pam.services = {
      greetd.enableGnomeKeyring = true;
      swaylock.enableGnomeKeyring = true;
    };

    programs.wireshark.enable = true;

    # NOTE: not graphical as such, but this is where it lived before: headless
    # hosts are built as images and provide their own boot configuration.
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
  };
}
