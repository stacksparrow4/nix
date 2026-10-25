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
    nix-flatpak.url = "github:gmodena/nix-flatpak?ref=latest";
    pi = {
      url = "github:earendil-works/pi";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    noctalia.url = "github:noctalia-dev/noctalia/cachix";

    blink-cmp = {
      url = "github:saghen/blink.cmp";
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
    inputs@{ flake-parts, ... }:
    let
      inherit (inputs.nixpkgs.lib) hasPrefix lists;
      inherit (inputs.nixpkgs.lib.fileset) toList fileFilter;
      mkImport =
        path:
        toList (fileFilter (f: f.hasExt "nix" && !(hasPrefix "_" f.name)) path);
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = lists.flatten [ (mkImport ./modules) ];
    };
}
