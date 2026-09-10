{
  flake.homeModules.term-tmux =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.sprrw.term.tmux.defaultTerm = lib.mkOption {
        type = lib.types.str;
        default = "foot";
      };

      config.programs.tmux = {
        enable = true;

        extraConfig =
          builtins.replaceStrings
            [ "REPLACE_WITH_DEFAULT_TERM" "REPLACE_WITH_PANE_CWD_CMD" ]
            [
              config.sprrw.term.tmux.defaultTerm
              (

                if pkgs.stdenv.isDarwin then "echo '#{pane_current_path}'" else "readlink /proc/#{pane_pid}/cwd"
              )
            ]
            (builtins.readFile ./tmux.conf);
      };
    };
}
