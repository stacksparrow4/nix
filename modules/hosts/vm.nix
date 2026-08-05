{
  inputs,
  config,
  withSystem,
  ...
}:

let
  nixosModules = config.flake.nixosModules;
  homeModules = config.flake.homeModules;
in
{
  # Throwaway headless VM image, built with `build-vm` (see the `sandbox`
  # aspect). Headless simply means it does not import `graphical`.
  flake.nixosConfigurations.vm = withSystem "x86_64-linux" (
    { pkgs, ... }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit pkgs;
      modules = [
        inputs.home-manager.nixosModules.home-manager

        {
          imports = with nixosModules; [
            base
            display
            locale
            nix-config
            users
            virt
          ];
        }

        {
          home-manager.users.sprrw = {
            imports = with homeModules; [
              base
              general
              general-linux
              misc
              sprrw-cli
              scripts

              term
              term-yazi-linux
              linux-term
              nvim

              programming
              sec
              ai
            ];

            home = {
              username = "sprrw";
              homeDirectory = "/home/sprrw";

              # The VM has no checkout of its own, so ship one.
              file."nixos".source = ../../.;
            };
          };
        }

        (
          { lib, ... }:
          {
            image.modules.iso.isoImage.squashfsCompression = null;

            boot.loader.timeout = lib.mkForce 1;

            networking.firewall.allowedTCPPorts = [ 22 ];
            services.openssh = {
              enable = true;
              ports = [ 22 ];
              settings = {
                PasswordAuthentication = true;
                AllowUsers = null; # Allows all users by default. Can be [ "user1" "user2" ]
                UseDns = true;
                X11Forwarding = false;
                PermitRootLogin = "prohibit-password"; # "yes", "without-password", "prohibit-password", "forced-commands-only", "no"
              };
            };

            users.users.sprrw.initialPassword = "password";

            networking.hostName = "vm";

            system.stateVersion = "24.11";
          }
        )
      ];
    }
  );
}
