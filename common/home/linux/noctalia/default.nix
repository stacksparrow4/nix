{
pkgs,
  config,
  lib,
  inputs,
  ...
}:

{
  imports = [ inputs.noctalia.homeModules.default ];

  config = lib.mkIf config.sprrw.linux.sway.enable {
    programs.noctalia = {
      enable = true;
    };

    home.file.".config/noctalia/main.toml".source = 
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/linux/noctalia/main.toml";

    home.packages = [(
      pkgs.writeShellApplication {
        name = "noctalia-reset";
        text = ''
          rm -f ~/.local/state/noctalia/settings.toml
          pkill noctalia || true
          nohup noctalia &>/dev/null &
        '';
      }
    )];
  };
}
