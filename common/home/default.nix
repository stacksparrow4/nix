{ pkgs, config, lib, ... }:

{
  imports = [
    ./ai
    ./linux
    ./nvim
    ./programming
    ./sec
    ./scripts
    ./term
    ./gui
    ./sandboxing.nix
    ./general.nix
    ./misc.nix
    ./payloads.nix
  ];

  options = {
    sprrw.nixosRepoPath = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
    };
  };

  config = {
    home.file.".config/nixpkgs/config.nix".source = ../../nixpkgs-config.nix;
    home.file.".config/.sprrw-nixos".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}";

    nix.extraOptions = lib.mkIf (!pkgs.stdenv.isDarwin) ''
      !include /home/sprrw/.local/nix-access-tokens.conf
    '';

    news.display = "silent";

    home.stateVersion = "24.11"; # Please read the comment before changing.

    programs.home-manager.enable = true;
  };
}
