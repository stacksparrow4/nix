{
  description = "ssparrow NixOS Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs-stable.url = "github:nixos/nixpkgs?ref=nixos-25.05";
  };

  outputs = { nixpkgs, nixpkgs-stable, home-manager, ... }@inputs:
  let
    overlay = system: import ./overlays.nix nixpkgs-stable.legacyPackages."${system}";
    nixpkgsOverlayed = system: import nixpkgs {
      inherit system;
      overlays = [ (overlay system) ];
    };
    overlayModule = { pkgs, ... }: {
      nixpkgs.overlays = [ (overlay pkgs.system) ];
    };
  in {
    nixosConfigurations.nest01 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        overlayModule
        ./hosts/nest01/system/configuration.nix
        home-manager.nixosModules.home-manager
        { home-manager.extraSpecialArgs = { inherit inputs; }; }
      ];
      specialArgs = { inherit inputs; };
    };

    nixosConfigurations.tanto = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        overlayModule
        ./hosts/tanto/system/configuration.nix
        home-manager.nixosModules.home-manager
        { home-manager.extraSpecialArgs = { inherit inputs; }; }
      ];
      specialArgs = { inherit inputs; };
    };

    packages.aarch64-darwin.homeConfigurations."dan" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgsOverlayed "aarch64-darwin";

      modules = [
        ./hosts/Daniels-MacBook-Air/home/default.nix
      ];

      extraSpecialArgs = { inputs = inputs; };
    };

    packages.x86_64-linux.homeConfigurations."kali" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgsOverlayed "x86_64-linux";

      modules = [
        ./hosts/kali/home/default.nix
      ];

      extraSpecialArgs = { inputs = inputs; osConfig.sprrw.font.mainFontMonoName = "IosevkaTerm Nerd Font Mono"; };
    };

    packages.x86_64-linux.docker = let
      pkgs = nixpkgsOverlayed "x86_64-linux";
    in
      pkgs.callPackage ./hosts/docker/docker.nix {
        home-manager = home-manager;
        inputs = inputs;
      };
  };
}
