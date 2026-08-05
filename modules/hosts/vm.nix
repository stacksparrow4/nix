{ inputs, withSystem, ... }:

let
  specialArgs =
    { self', pkgs-unstable, ... }:
    {
      inherit inputs self' pkgs-unstable;
    };
in
{
  flake.nixosConfigurations.vm = withSystem "x86_64-linux" (
    args@{ pkgs, ... }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit pkgs;
      specialArgs = specialArgs args;
      modules = [
        ../../hosts/vm/system/configuration.nix
        inputs.home-manager.nixosModules.home-manager
        { home-manager.extraSpecialArgs = specialArgs args; }
      ];
    }
  );
}
