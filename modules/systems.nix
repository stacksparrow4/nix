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
    let
      linuxify =
        pkgs:
        if pkgs.stdenv.hostPlatform.isLinux then
          pkgs
        else
          import inputs.nixpkgs { system = "${pkgs.stdenv.hostPlatform.parsed.cpu.name}-linux"; };
    in
    { system, ... }:
    {
      _module.args = rec {
        pkgs = import inputs.nixpkgs {
          inherit system;
          config = nixpkgsConfig;
        };

        pkgs-unstable = import inputs.nixpkgs-unstable {
          inherit system;
          config = nixpkgsConfig;
        };

        pkgs-linux = linuxify pkgs;
        pkgs-linux-unstable = linuxify pkgs-unstable;
      };
    };
}
