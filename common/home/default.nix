{ lib, ... }:

{
  imports = [
    ./docker.nix
    ./linux
    ./nvim
    ./programming
    ./sec
    ./scripts
    ./term
    ./gui
    ./sandboxing.nix
  ];

  options = {
    sprrw.nixosRepoPath = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
    };
  };

  config = {
    home.file.".config/nixpkgs/config.nix".text = ''
      { allowUnfree = true; }
    '';

    home.stateVersion = "24.11"; # Please read the comment before changing.

    programs.home-manager.enable = true;
  };
}
