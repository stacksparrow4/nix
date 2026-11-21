{
  perSystem =
    { pkgs, ... }:
    {
      packages.zsh = pkgs.callPackage (
        {
          lib,
          pkgs,
          prompt ? "\n%B%F{cyan} %1~ %(!.#.$)%f%b ",
          shellExtra ? "",
          sessionVariablesPackage ? null,
          ...
        }:

        let
          sessionVars =
            if sessionVariablesPackage != null then
              ''
                source ${lib.escapeShellArg "${sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh"}
              ''
            else
              ''
                if [[ -r "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]]; then
                  source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
                fi
              '';

          zshenv = ''
            ${sessionVars}
          '';

          zshrc = ''
            typeset -U path cdpath fpath manpath

            for profile in ''${(z)NIX_PROFILES}; do
              fpath+=($profile/share/zsh/site-functions $profile/share/zsh/$ZSH_VERSION/functions $profile/share/zsh/vendor-completions)
            done
            fpath=(${pkgs.nix-zsh-completions}/share/zsh/site-functions $fpath)

            HELPDIR="${pkgs.zsh}/share/zsh/$ZSH_VERSION/help"
          ''
          + (builtins.readFile ./zshrc)
          + ''
            eval "$(${pkgs.coreutils}/bin/dircolors -b)"

            PROMPT=${lib.escapeShellArg prompt}

            ${shellExtra}
          '';

          zshConfig = pkgs.symlinkJoin {
            name = "zsh-config";
            paths = [
              (pkgs.writeTextDir ".zshenv" zshenv)
              (pkgs.writeTextDir ".zshrc" zshrc)
            ];
          };
        in
        pkgs.runCommand "zsh"
          {
            nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
            passthru.shellPath = "/bin/zsh";
          }
          ''
            makeBinaryWrapper ${pkgs.zsh}/bin/zsh $out/bin/zsh --inherit-argv0 --set ZDOTDIR ${zshConfig}
          ''
      ) { };
    };
}
