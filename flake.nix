{
  description = "ssparrow NixOS Flake";

  inputs = {
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
    {
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      ...
    }@inputs:
    let
      nixpkgsConfig = import ./nixpkgs-config.nix;
      overlay =
        system:
        import ./overlays.nix (
          import nixpkgs-unstable {
            inherit system;
            config = nixpkgsConfig;
          }
        );
      overlayedNixpkgs =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ (overlay system) ];
          config = nixpkgsConfig;
        };
    in
    {
      nixosConfigurations.nest01 = nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        pkgs = overlayedNixpkgs system;
        modules = [
          ./hosts/nest01/system/configuration.nix
          home-manager.nixosModules.home-manager
          { home-manager.extraSpecialArgs = { inherit inputs; }; }
        ];
        specialArgs = { inherit inputs; };
      };

      nixosConfigurations.vm = nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        pkgs = overlayedNixpkgs system;
        modules = [
          ./hosts/vm/system/configuration.nix
          home-manager.nixosModules.home-manager
          { home-manager.extraSpecialArgs = { inherit inputs; }; }
        ];
        specialArgs = { inherit inputs; };
      };

      packages.aarch64-darwin.homeConfigurations."dan" = home-manager.lib.homeManagerConfiguration {
        pkgs = overlayedNixpkgs "aarch64-darwin";

        modules = [
          ./hosts/Daniels-MacBook-Air/home/default.nix
        ];

        extraSpecialArgs = {
          inputs = inputs;
        };
      };
    };
}
