{
  pkgs,
  config,
  lib,
  ...
}:

{
  imports = [
    ./apps.nix
    ./audio.nix
    ./display.nix
    ./fonts.nix
    ./locale.nix
    ./nix-config.nix
    ./users.nix
    ./virt.nix
    ./flatpak.nix
    ./vms
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
      environment.etc =
        let
          hmConfig = config.home-manager.users.sprrw;
        in
        {
          "hm-package".source = hmConfig.home.activationPackage;
        };

      # TODO: is this needed
      boot.blacklistedKernelModules = [
        "esp4"
        "esp6"
      ];
      boot.extraModprobeConfig = ''
        install esp4 ${pkgs.coreutils}/bin/false
        install esp6 ${pkgs.coreutils}/bin/false
      '';

      boot.tmp.cleanOnBoot = true;

      boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;

      networking.networkmanager.enable = lib.mkDefault true;
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

      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
    })
  ];
}
