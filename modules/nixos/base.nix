{
  flake.nixosModules.base =
    {
      pkgs,
      config,
      lib,
      ...
    }:
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
    };
}
