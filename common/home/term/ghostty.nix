{ pkgs, lib, config, osConfig, ... }:

{
  options = {
    sprrw.term.ghostty = {
      enable = lib.mkEnableOption "ghostty";

      font = {
        family = lib.mkOption {
          type = lib.types.str;
          default = osConfig.sprrw.font.mainFontMonoName;
        };

        size = lib.mkOption {
          type = lib.types.int;
          default = 13;
        };
      };

      installTerminfo = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
    };
  };

  config = let
    cfg = config.sprrw.term.ghostty;
  in {
    home.file.".terminfo" = lib.mkIf cfg.installTerminfo {
      source = "${pkgs.ghostty.terminfo}/share/terminfo";
    };

    programs.ghostty = lib.mkIf cfg.enable {
      enable = true;

      settings = {
        font-family = "${cfg.font.family}";
        font-size = cfg.font.size;
        window-decoration = "none";
        theme = "Carbonfox";
        command = "${pkgs.tmux}/bin/tmux";
        resize-overlay = "never";
        maximize = true;
      };
    };
  };
}
