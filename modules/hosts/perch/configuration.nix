{
  self,
  inputs,
  moduleWithSystem,
  ...
}:

{
  flake.nixosConfigurations.perch = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      (moduleWithSystem (
        { self', ... }:
        {
          lib,
          ...
        }:
        {
          imports = [
            ./_hardware-configuration.nix
            inputs.nixos-apple-silicon.nixosModules.apple-silicon-support
            inputs.home-manager.nixosModules.home-manager
          ]
          ++ (with self.modules.nixos; [
            base
            workstation
            locale
            nix-config
            users
            tailscale
          ]);

          home-manager.users.sprrw = {
            imports = with self.modules.homeManager; [
              base
              general
              general-linux
              misc
              sandbox

              term
              yazi-linux
              linux
              nvim

              programming

              gui

              pi
            ];

            home = {
              username = "sprrw"; # TODO: shouldnt this be in a module
              homeDirectory = "/home/sprrw";

              file.".background-image".source = ./bg.jpg;

              packages = with self'.packages; [
                sprrw
              ];
            };
          };

          nixpkgs.config = import ../../../nixpkgs-config.nix; # TODO: Should this be in the nix-config nixosModule?

          boot.loader.timeout = lib.mkForce 1;

          swapDevices = [
            {
              device = "/swapfile";
              size = 16 * 1024;
            }
          ];

          hardware.asahi = {
            enable = true;
            pkgs = lib.mkForce (
              import inputs.nixos-apple-silicon.inputs.nixpkgs {
                system = "aarch64-linux";
                overlays = [ inputs.nixos-apple-silicon.overlays.default ];
              }
            );
            peripheralFirmwareDirectory = null;
          };

          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = false;

          networking.hostName = "perch";

          networking.networkmanager = {
            enable = true;
            wifi.backend = "iwd";
          };

          nix.settings = {
            extra-substituters = [ "https://nix-community.cachix.org" ];
            extra-trusted-public-keys = [
              "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            ];
          };

          system.stateVersion = "26.11";
        }
      ))
    ];
  };
}
