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

          zshrc = lib.replaceStrings
            [
              "@nix_zsh_completions@"
              "@zsh@"
              "@prompt@"
              "@coreutils@"
              "@shell_extra@"
            ]
            [
              "${pkgs.nix-zsh-completions}"
              "${pkgs.zsh}"
              (lib.escapeShellArg prompt)
              "${pkgs.coreutils}"
              shellExtra
            ]
            (builtins.readFile ./zshrc);

          zshConfig = pkgs.symlinkJoin {
            name = "zsh-config";
            paths = [
              (pkgs.writeTextDir ".zshenv" zshenv)
              (pkgs.writeTextDir ".zshrc" zshrc)
            ];
          };
        in
        pkgs.runCommand "zsh" { nativeBuildInputs = [ pkgs.makeBinaryWrapper ]; } ''
          makeBinaryWrapper ${pkgs.zsh}/bin/zsh $out/bin/zsh --inherit-argv0 --set ZDOTDIR ${zshConfig}
        ''
      ) { };
    };
}
