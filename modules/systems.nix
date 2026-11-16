{ inputs, ... }:

{
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  perSystem =
    { system, ... }:
    let
      nixpkgsConfig = import ../nixpkgs-config.nix;
    in
    {
      _module.args = {
        pkgs = import inputs.nixpkgs {
          inherit system;
          config = nixpkgsConfig;
        };

        pkgsUnstable = import inputs.nixpkgs-unstable {
          inherit system;
          config = nixpkgsConfig;
        };
      };
    };
}
