{ pkgs, lib, config, osConfig, ... }:

let cfg = config.sprrw.alacritty; in {
  options = {
    sprrw.alacritty = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.alacritty = {
      enable = true;
      settings = {
        window = {
          startup_mode = "Maximized";
          option_as_alt = "Both";
        };

        keyboard.bindings = lib.mkIf config.sprrw.macosMode [
          { key = "Right"; mods = "Alt"; chars = "\\u001BF"; }
          { key = "Left";  mods = "Alt"; chars = "\\u001BB"; }
          { key = "Left";  mods = "Command"; chars = "\\u0001"; }
          { key = "Right"; mods = "Command"; chars = "\\u0005"; }
        ];

        font = {
          normal = { family = if config.sprrw.macosMode then "IosevkaTerm Nerd Font Mono" else osConfig.sprrw.font.mainFontMonoName; };
          size = if config.sprrw.macosMode then 14 else 13;
        };

        env.TERM = "xterm-256color";

        terminal.shell.program = "${pkgs.tmux}/bin/tmux";
      };
    };
  };
}
