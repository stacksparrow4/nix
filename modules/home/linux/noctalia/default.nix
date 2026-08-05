{ inputs, moduleWithSystem, ... }:

{
  flake.homeModules.linux-noctalia = moduleWithSystem (
    { self', ... }:
    { config, ... }:
    {
      imports = [ inputs.noctalia.homeModules.default ];

      programs.noctalia.enable = true;

      home.file.".config/noctalia/main.toml".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/modules/home/linux/noctalia/main.toml";

      home.packages = [ self'.packages.noctalia-reset ];
    }
  );
}
