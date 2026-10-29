{
  inputs,
  config,
  withSystem,
  ...
}:

let
  nixosModules = config.flake.modules.nixos;
  homeModules = config.flake.modules.homeManager;
in
{
  flake.nixosConfigurations.vm = withSystem "x86_64-linux" (
    { pkgs, ... }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit pkgs;
      modules = [
        inputs.home-manager.nixosModules.home-manager

        (
          { lib, modulesPath, ... }:
          {
            imports = with nixosModules; [
              base
              locale
              nix-config
              users
              virt
            ] ++ [ "${modulesPath}/profiles/qemu-guest.nix" ];

            home-manager.users.sprrw = {
              imports = with homeModules; [
                base
                general
                general-linux
                misc

                term
                yazi-linux
                linux-tools
                nvim

                programming
                sec

                sandbox
              ];

              home = {
                username = "sprrw";
                homeDirectory = "/home/sprrw";

                file."nixos".source = ../../.;
              };
            };

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
