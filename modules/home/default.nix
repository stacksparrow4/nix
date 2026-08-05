# The always-imported home aspect: the two cross-cutting *data* options
# (`nixosRepoPath`, `term.shellExtra`) plus the handful of settings every host
# needs. Both options are declared here rather than next to their main consumer
# because they are read and written across unrelated aspects (`term-foot`,
# `linux-sway`, `ai-pi`, `programming-git`, `nvim`, …) and hosts import those
# aspects individually.
{
  flake.homeModules.base =
    { config, lib, ... }:
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
        home.file.".config/.sprrw-nixos".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}";

        news.display = "silent";

        home.stateVersion = "24.11"; # Please read the comment before changing.

        programs.home-manager.enable = true;
      };
    };
}
