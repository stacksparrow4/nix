{ inputs, withSystem, ... }:

let
  specialArgs =
    { self', pkgs-unstable, ... }:
    {
      inherit inputs self' pkgs-unstable;
    };
in
{
  flake.homeConfigurations.dan = withSystem "aarch64-darwin" (
    args@{ pkgs, ... }:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [ ../../hosts/Daniels-MacBook-Air/home/default.nix ];
      extraSpecialArgs = specialArgs args;
    }
  );
}
