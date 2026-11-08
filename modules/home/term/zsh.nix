{
  flake.modules.homeManager.zsh =
    { config, lib, ... }:
    {
      options.sprrw.term.zsh.prompt = lib.mkOption {
        type = lib.types.str;
        default = "\n%B%F{cyan} %1~ %(!.#.$)%f%b ";
      };

      config.programs.zsh = {
        enable = true;
        defaultKeymap = "viins";

        initContent = ''
          KEYTIMEOUT=1
          PROMPT=${lib.escapeShellArg config.sprrw.term.zsh.prompt}

          bindkey -M viins '^P' up-line-or-history
          bindkey -M viins '^N' down-line-or-history
          bindkey -M viins '^L' clear-screen
          bindkey -M viins '\e.' insert-last-word
          bindkey -M viins '\e[1;3C' forward-word
          bindkey -M viins '\e[1;3D' backward-word

          function zle-keymap-select {
            if [[ $KEYMAP == vicmd ]]; then
              printf '\e[2 q'
            else
              printf '\e[6 q'
            fi
          }
          zle -N zle-keymap-select

          function zle-line-init {
            printf '\e[6 q'
          }
          zle -N zle-line-init

          autoload -Uz select-quoted select-bracketed
          zle -N select-quoted
          zle -N select-bracketed
          for m in visual viopp; do
            for c in {a,i}{\',\",\`}; do
              bindkey -M $m $c select-quoted
            done
            for c in {a,i}''${(s..)^:-'()[]{}<>bB'}; do
              bindkey -M $m $c select-bracketed
            done
          done

          autoload -Uz edit-command-line
          zle -N edit-command-line
          bindkey -M viins '^X^E' edit-command-line
          bindkey -M vicmd '^X^E' edit-command-line
        ''
        + "\n"
        + config.sprrw.term.shellExtra;
      };
    };
}
