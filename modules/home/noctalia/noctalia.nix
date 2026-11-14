{ inputs, ... }:

{
  flake.modules.homeManager.noctalia =
    { config, ... }:
    {
      imports = [ inputs.noctalia.homeModules.default ];

      programs.noctalia.enable = true;

      home.file.".config/noctalia/main.toml".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/modules/home/noctalia/main.toml";
    };
}
