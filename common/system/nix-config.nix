{ inputs, lib, ... }:

{
  # Necessary for using flakes on this system.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Pin registry to flake versions
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.registry.home-manager.flake = inputs.home-manager;
  nix.channel.enable = false;

  nix.nixPath = [
    "nixpkgs=${inputs.nixpkgs}"
    "nixpkgs-unstable=${inputs.nixpkgs-unstable}"
  ];

  programs.nix-ld.enable = true;
}
