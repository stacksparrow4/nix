{
  flake.modules.homeManager.navi =
    { pkgs, config, ... }:
    {
      home.packages = [ pkgs.navi ];

      home.file.".local/share/navi/cheats".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/modules/home/term/navi/cheats";
    };
}
