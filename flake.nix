{
  description = "ssparrow NixOS Flake";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";

    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager?ref=release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvirt = {
      url = "github:stacksparrow4/NixVirt?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia.url = "github:noctalia-dev/noctalia/cachix";

    crane.url = "github:ipetkov/crane";

    nvim-http-client = {
      url = "github:stacksparrow4/nvim-http-client?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pwnproxy = {
      url = "github:stacksparrow4/pwnproxy?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    autorize = {
      url = "github:stacksparrow4/autorize?ref=main";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nvim-http-client.follows = "nvim-http-client";
      };
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { withSystem, ... }:
      let
        nixpkgsConfig = import ./nixpkgs-config.nix;

        specialArgs =
          {
            self',
            pkgs-unstable,
            ...
          }:
          {
            inherit
              inputs
              self'
              pkgs-unstable
              ;
          };

        mkNixosSystem =
          system: module:
          withSystem system (
            args@{ pkgs, ... }:
            inputs.nixpkgs.lib.nixosSystem {
              inherit pkgs;
              specialArgs = specialArgs args;
              modules = [
                module
                inputs.home-manager.nixosModules.home-manager
                { home-manager.extraSpecialArgs = specialArgs args; }
              ];
            }
          );
      in
      {
        imports = [ ./pkgs ];

        systems = [
          "x86_64-linux"
          "aarch64-darwin"
        ];

        perSystem =
          { system, ... }:
          let
            pkgs-unstable = import inputs.nixpkgs-unstable {
              inherit system;
              config = nixpkgsConfig;
            };
          in
          {
            _module.args = {
              inherit pkgs-unstable;

              pkgs = import inputs.nixpkgs {
                inherit system;
                config = nixpkgsConfig;
              };
            };
          };

        flake = {
          nixosConfigurations = {
            nest01 = mkNixosSystem "x86_64-linux" ./hosts/nest01/system/configuration.nix;
            vm = mkNixosSystem "x86_64-linux" ./hosts/vm/system/configuration.nix;
          };

          homeConfigurations.dan = withSystem "aarch64-darwin" (
            args@{ pkgs, ... }:
            inputs.home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              modules = [ ./hosts/Daniels-MacBook-Air/home/default.nix ];
              extraSpecialArgs = specialArgs args;
            }
          );
        };
      }
    );
}
