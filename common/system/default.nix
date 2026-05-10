{ pkgs, config, lib, ... }:

{
  imports = [
    ./apps.nix
    ./audio.nix
    ./display.nix
    ./fonts.nix
    ./nix-config.nix
    ./virt.nix
    ./flatpak.nix
  ];

  # For now just putting all options in default.nix
  options.sprrw = {
    headless = lib.mkEnableOption "headless";
  };

  config = lib.mkMerge [
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
      };

      # Place home-files in a place that can easily be mounted by containers
      environment.etc."hm-package" = {
        source = config.home-manager.users.sprrw.home.activationPackage;
      };

      systemd.coredump.enable = true;
      systemd.coredump.extraConfig = ''
        Storage=none
        ProcessSizeMax=0
      '';

      boot.kernelPackages = lib.mkIf (lib.versionOlder pkgs.linux.version "6.18.22") pkgs.linuxPackages_6_18;

      boot.blacklistedKernelModules = [ "esp4" "esp6" ];
      boot.extraModprobeConfig = ''
        install esp4 ${pkgs.coreutils}/bin/false
        install esp6 ${pkgs.coreutils}/bin/false
      '';
    }
    (lib.mkIf (!config.sprrw.headless) {
      programs._1password.enable = true;
      programs._1password-gui.enable = true;

      services.gnome.gnome-keyring.enable = true;
      security.pam.services = {
        greetd.enableGnomeKeyring = true;
        swaylock.enableGnomeKeyring = true;
      };

      programs.wireshark.enable = true;
    })
  ];
}
