{ lib, config, ... }:

{
  options = {
    sprrw.term.tmux.enable = lib.mkEnableOption "tmux";
  };

  config = lib.mkIf config.sprrw.term.tmux.enable {
    programs.tmux = {
      enable = true;

      extraConfig = builtins.readFile ./tmux.conf;
    };
  };
}
