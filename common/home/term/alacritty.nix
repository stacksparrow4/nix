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
    };
  };

  config = let
    cfg = config.sprrw.term.alacritty;
  in lib.mkIf cfg.enable {
    programs.alacritty = {
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
      };
    };
  };
}
