{ moduleWithSystem, ... }:

{
  flake.modules.homeManager.base = moduleWithSystem (
    { self', ... }:
    { lib, ... }:
    {
      options.sprrw = {
        nixosRepoPath = lib.mkOption {
          type = lib.types.str;
          default = "nixos";
        };

        term.shellExtra = lib.mkOption {
          type = lib.types.lines;
          default = "";
        };
      };

      config = {
        home.file.".config/nixpkgs/config.nix".source = ../../nixpkgs-config.nix;

        home = {
          username = "sprrw";
          homeDirectory = "/home/sprrw";

          packages = with self'.packages; [ sprrw ];
        };

        news.display = "silent";

        home.stateVersion = "24.11";

        programs.home-manager.enable = true;
      };
    }
  );
}
