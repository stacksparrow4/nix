{ lib, config, ... }:

{
  options.sprrw.term.tmux = {
    enable = lib.mkEnableOption "tmux";

    defaultTerm = lib.mkOption {
      type = lib.types.str;
      default = "foot";
    };
  };

  config = let
    cfg = config.sprrw.term.tmux;
  in lib.mkIf cfg.enable {
    programs.tmux = {
      enable = true;

      extraConfig =
        builtins.replaceStrings [ "REPLACE_WITH_DEFAULT_TERM" ] [ cfg.defaultTerm ]
          (builtins.readFile ./tmux.conf);
    };
  };
}
