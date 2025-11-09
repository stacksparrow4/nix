{ pkgs, lib, config, osConfig, ... }:

{
  options = {
    sprrw.term.alacritty = {
      enable = lib.mkEnableOption "alacritty";

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

      bindings = lib.mkOption {
        default = [];
      };

      installTerminfo = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };
  };

  config = let
    cfg = config.sprrw.term.alacritty;
  in {
    home.file.".terminfo" = lib.mkIf cfg.installTerminfo {
      source = "${pkgs.alacritty.terminfo}/share/terminfo";
    };

    programs.alacritty = lib.mkIf cfg.enable {
      enable = true;
      settings = {
        window = {
          startup_mode = "Maximized";
          option_as_alt = "Both";
        };

        keyboard.bindings = cfg.bindings;

        font = {
          normal = { family = cfg.font.family; };
          size = cfg.font.size;
        };

        terminal.shell.program = "${pkgs.tmux}/bin/tmux";

        env.TERMINFO_DIRS = lib.mkIf cfg.installTerminfo "\$HOME/.terminfo";
      };
    };
  };
}
