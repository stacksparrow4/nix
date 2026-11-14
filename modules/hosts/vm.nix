{
  inputs,
  self,
  withSystem,
  ...
}:

{
  flake.nixosConfigurations.vm = withSystem "x86_64-linux" (
    { pkgs, ... }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit pkgs;
      modules = [
        inputs.home-manager.nixosModules.home-manager
      ]
      ++ (with self.modules.nixos; [
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

              home.file."nixos".source = ../../.;
            };

            networking.firewall.allowedTCPPorts = [ 22 ];
            services.openssh.enable = true;

            users.users.sprrw.initialPassword = "password";

            networking.hostName = "vm";

            system.stateVersion = "24.11";
          }
        )
      ];
    }
  );
}
