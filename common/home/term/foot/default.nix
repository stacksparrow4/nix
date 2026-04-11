{
  pkgs,
  lib,
  config,
  ...
}:

{
  options = {
    sprrw.term.foot = {
      enable = lib.mkEnableOption "foot";

      installTerminfo = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
    };
  };

  config =
    let
      cfg = config.sprrw.term.foot;
    in lib.mkIf cfg.enable {
      home.file.".terminfo" = lib.mkIf cfg.installTerminfo {
        source = "${pkgs.foot.terminfo}/share/terminfo";
      };

      home.file.".config/foot/foot.ini".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${config.sprrw.nixosRepoPath}/common/home/term/foot/foot.ini";
    };
}
