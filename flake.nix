{
  description = "ssparrow NixOS Flake";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:denful/import-tree";

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
    inputs@{ flake-parts, import-tree, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (import-tree ./modules);
}
