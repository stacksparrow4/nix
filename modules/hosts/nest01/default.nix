{
  inputs,
  config,
  withSystem,
  ...
}:

let
  nixosModules = config.flake.nixosModules;
in
{
  flake.nixosModules.gaming = {
    programs.steam = {
      enable = true;
      # remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      # dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      # localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    };
  };

  flake.nixosConfigurations.nest01 = withSystem "x86_64-linux" (
    { self', pkgs-unstable, ... }:
    inputs.nixpkgs.lib.nixosSystem {
      modules = [
        inputs.home-manager.nixosModules.home-manager

        {
          imports = with nixosModules; [
            nest01-hardware
            base
            display
            graphical
            gaming
            locale
            nix-config
            users
            virt
          ];
        }

        # TRANSITIONAL: the home side is still the old common/home tree, which
        # wants these via extraSpecialArgs. Removed once home is converted.
        {
          home-manager.extraSpecialArgs = {
            inherit inputs self' pkgs-unstable;
          };
          home-manager.users.sprrw = ../../../hosts/nest01/home;
        }

        (
          { lib, config, ... }:
          {
            nixpkgs.config = import ../../../nixpkgs-config.nix;

            boot.loader.timeout = lib.mkForce 9999;

            swapDevices = [
              {
                device = "/swapfile";
                size = 32 * 1024;
              }
            ];

            services.fstrim = {
              enable = true;
              interval = "weekly";
            };

            networking.hostName = "nest01";
            networking.extraHosts = ''
              192.9.173.108 kubernetes.default
            '';

            hardware.graphics = {
              enable = true;
            };
            hardware.nvidia = {
              modesetting.enable = true;
              powerManagement.enable = false;
              powerManagement.finegrained = false;
              open = false;
              nvidiaSettings = true;
              package = config.boot.kernelPackages.nvidiaPackages.stable;
            };
            services.xserver.videoDrivers = [ "nvidia" ];

            hardware.opentabletdriver.enable = true;
            hardware.opentabletdriver.daemon.enable = true;

            # This value determines the NixOS release from which the default
            # settings for stateful data, like file locations and database
            # versions on your system were taken. It's perfectly fine and
            # recommended to leave this value at the release version of the
            # first install of this system.
            system.stateVersion = "24.11";
          }
        )
      ];
    }
  );
}
