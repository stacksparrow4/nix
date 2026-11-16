{
  inputs,
  self,
  ...
}:

{
  flake.nixosConfigurations.vm = inputs.nixpkgs.lib.nixosSystem {
    modules =
      (with self.modules.nixos; [
        base
        locale
        nix-config
        users
        podman
      ])
      ++ [
        (
          { modulesPath, ... }:
          {
            imports = [ "${modulesPath}/profiles/qemu-guest.nix" ];

            home-manager.users.sprrw = {
              imports = with self.modules.homeManager; [
                base
                general
                misc
                term
                nvim
                programming
                sec
                sandbox
              ];

              home.file."nixos".source = ../../.;
            };

            nixpkgs.hostPlatform = "x86_64-linux";

            networking.firewall.allowedTCPPorts = [ 22 ];
            services.openssh.enable = true;

            users.users.sprrw.initialPassword = "password";

            networking.hostName = "vm";

            system.stateVersion = "24.11";
          }
        )
      ];
  };
}
