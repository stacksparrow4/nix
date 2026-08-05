{
  flake.homeModules.term-tmux =
    { config, lib, ... }:
    {
      options.sprrw.term.tmux.defaultTerm = lib.mkOption {
        type = lib.types.str;
        default = "foot";
      };

      config.programs.tmux = {
        enable = true;

        extraConfig =
          builtins.replaceStrings [ "REPLACE_WITH_DEFAULT_TERM" ] [ config.sprrw.term.tmux.defaultTerm ]
            (builtins.readFile ./tmux.conf);
      };
    };
}
