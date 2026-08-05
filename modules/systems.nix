{ inputs, ... }:

let
  nixpkgsConfig = import ../nixpkgs-config.nix;
in
{
  systems = [
    "x86_64-linux"
    "aarch64-darwin"
  ];

  perSystem =
    { system, ... }:
    {
      _module.args = {
        pkgs = import inputs.nixpkgs {
          inherit system;
          config = nixpkgsConfig;
        };

        pkgs-unstable = import inputs.nixpkgs-unstable {
          inherit system;
          config = nixpkgsConfig;
        };
      };
    };
}
