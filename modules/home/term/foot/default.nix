{ moduleWithSystem, ... }:

{
  flake.homeModules.term-foot = moduleWithSystem (
    { self', ... }:
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      options.sprrw.term.foot.installTerminfo = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };

      config = {
        home.packages = [
          self'.packages.foot
          pkgs.xdg-terminal-exec
        ];

        xdg.configFile."xdg-terminals.list".text = ''
          foot.desktop
        '';

        home.file.".terminfo/f" = lib.mkIf config.sprrw.term.foot.installTerminfo {
          source = "${self'.packages.foot.terminfo}/share/terminfo/f";
        };
      };
    }
  );
}
