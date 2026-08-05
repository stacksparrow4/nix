{
  flake.homeModules.term-foot =
    { pkgs, config, lib, ... }:
    {
      options.sprrw.term.foot.installTerminfo = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };

      config = {
        home.packages = with pkgs; [
          foot # Even though already included by NixOS its here so home-manager can see the desktop file
          xdg-terminal-exec
        ];

        xdg.configFile."xdg-terminals.list".text = ''
          foot.desktop
        '';

        home.file.".terminfo/f" = lib.mkIf config.sprrw.term.foot.installTerminfo {
          source = "${pkgs.foot.terminfo}/share/terminfo/f";
        };

        home.file.".config/foot/foot.ini".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/modules/home/term/foot/foot.ini";
      };
    };
}
