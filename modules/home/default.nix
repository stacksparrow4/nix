{
  flake.homeModules.base =
    { lib, ... }:
    {
      options.sprrw = {
        nixosRepoPath = lib.mkOption {
          type = lib.types.str;
          default = "nixos";
          description = "Path of this repo's checkout, relative to $HOME.";
        };

        term.shellExtra = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Shell snippet appended to both the bash and zsh rc files.";
        };
      };

      config = {
        home.file.".config/nixpkgs/config.nix".source = ../../nixpkgs-config.nix;

        news.display = "silent";

        home.stateVersion = "24.11"; # Please read the comment before changing.

        programs.home-manager.enable = true;
      };
    };
}
