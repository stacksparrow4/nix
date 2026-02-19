{ pkgs, lib, config, osConfig, ... }:

{
  options = {
    sprrw.term.foot = {
      enable = lib.mkEnableOption "foot";

      font = {
        family = lib.mkOption {
          type = lib.types.str;
          default = osConfig.sprrw.font.mainFontMonoName;
        };

        size = lib.mkOption {
          type = lib.types.int;
          default = 11;
        };
      };

      installTerminfo = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
    };
  };

  config = let
    cfg = config.sprrw.term.foot;
  in {
    home.file.".terminfo" = lib.mkIf cfg.installTerminfo {
      source = "${pkgs.foot.terminfo}/share/terminfo";
    };

    programs.foot = lib.mkIf cfg.enable {
      enable = true;

      settings = {
        main = {
          font = "${cfg.font.family}:size=${toString cfg.font.size}";
        };
      };
    };
  };
}
