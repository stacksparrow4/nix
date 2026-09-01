{
  flake.nixosModules.base =
    {
      config,
      lib,
      ...
    }:
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
      };

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

      # Place home-files in a place that can easily be mounted by containers
      environment.etc =
        let
          hmConfig = config.home-manager.users.sprrw;
        in
        {
          "hm-package".source = hmConfig.home.activationPackage;
        };

      boot.tmp.cleanOnBoot = true;

      boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;

      networking.networkmanager.enable = lib.mkDefault true;
    };
}
