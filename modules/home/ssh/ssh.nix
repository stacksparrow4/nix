{
  flake.modules.homeManager.ssh = { config, ... }: {
    home.file.".ssh/config".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/modules/home/ssh/ssh.config";
  };
}
