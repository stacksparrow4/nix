{ pkgs, lib, config, ... }:

{
  options.sprrw.term.yazi.enable = lib.mkEnableOption "yazi";

  config = lib.mkIf config.sprrw.term.yazi.enable {
    programs.yazi = {
      enable = true;
      keymap = {
        mgr.prepend_keymap = [
          { run = "quit"; on = [ "<Esc>" ]; }
          { run = "remove --permanently"; on = [ "d" ]; }
        ];
      };
    };
  };
}
