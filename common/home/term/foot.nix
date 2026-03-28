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
          default = 12;
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

        colors = {
          background = "000000";
          foreground = "c0caf5";
          regular0 = "1D202F";
          regular1 = "f7768e";
          regular2 = "9ece6a";
          regular3 = "e0af68";
          regular4 = "7aa2f7";
          regular5 = "bb9af7";
          regular6 = "5996f9";
          regular7 = "a9b1d6";
          bright0 = "414868";
          bright1 = "f7768e";
          bright2 = "9ece6a";
          bright3 = "e0af68";
          bright4 = "7aa2f7";
          bright5 = "bb9af7";
          bright6 = "5996f9";
          bright7 = "c0caf5";
        };
      };
    };
  };
}
