{ config, ... }:

{
  flake.modules.homeManager.aliases = {
    sprrw.term.shellExtra = ''
      alias ls='ls --color=auto'

      alias cdtmp='cd "$(mktemp -d)"'

      function take() {
        if [[ $# -ne 1 ]]; then
          echo "Usage: take <dir>"
        fi
        mkdir "$1"
        cd "$1"
      }

      function rl() {
        local mypath
        if echo "$1" | grep -qE "^/"; then
          mypath="$1"
        else
          if ! which "$1" >/dev/null; then
            echo "Failed to find binary"
            return 1
          fi
          mypath=$(which "$1")
        fi

        while [ -L "$mypath" ]; do
          echo "$mypath"
          mypath=$(readlink "$mypath")
        done

        echo "$mypath"
      }

      function ns() {
        if [[ -n "$BASH_VERSINFO" ]]; then
          history -a
        fi
        nix-shell -p "$@"
      }

      function ns-unstable() {
        if [[ -n "$BASH_VERSINFO" ]]; then
          history -a
        fi
        NIXPKGS_ALLOW_UNFREE=1 nix shell --impure $(for i in "$@"; do echo -n ' github:NixOS/nixpkgs/nixos-unstable#'"$i"; done)
      }

      alias nss='nix-search --channel=26.05 -d -m 3'
      alias nss-unstable='nix-search --channel=unstable -d -m 3'

      export UV_LINK_MODE=symlink

      alias nixurl='nix store prefetch-file'
    '';
  };

  flake.modules.homeManager.term = {
    imports = with config.flake.modules.homeManager; [
      aliases
      bash
      foot
      navi
      tmux
      yazi
      zshrc
    ];
  };
}
