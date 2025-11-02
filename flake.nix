{
  description = "ssparrow NixOS Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    home-manager.url = "github:nix-community/home-manager?ref=release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs:
  let
    overlay = system: import ./overlays.nix (import nixpkgs-unstable { inherit system; config.allowUnfree = true; });
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

    packages.x86_64-linux.homeConfigurations."docker" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgsOverlayed "x86_64-linux";

      modules = [
        ./hosts/docker/home/default.nix
      ];

      extraSpecialArgs = { inputs = inputs; };
    };
  };
}
