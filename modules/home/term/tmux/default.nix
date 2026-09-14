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
            [ "REPLACE_WITH_DEFAULT_TERM" "REPLACE_WITH_SPLITS" ]
            [
              config.sprrw.term.tmux.defaultTerm
              (

                if pkgs.stdenv.isDarwin then
                  ''
                    bind c new-window -c "#{pane_current_path}"
                    bind s split-window -c "#{pane_current_path}"
                    bind a split-window -h -c "#{pane_current_path}"
                  ''
                else
                  ''
                    bind c run-shell 'tmux new-window -c "$(readlink /proc/#{pane_pid}/cwd)"'
                    bind s run-shell 'tmux split-window -c "$(readlink /proc/#{pane_pid}/cwd)"'
                    bind a run-shell 'tmux split-window -h -c "$(readlink /proc/#{pane_pid}/cwd)"'
                  ''
              )
            ]
            (builtins.readFile ./tmux.conf);
      };
    };
}
