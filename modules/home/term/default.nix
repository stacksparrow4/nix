{ config, ... }:

{
  flake.modules.homeManager.aliases = {
    sprrw.term.shellExtra = ''
      alias ls='ls --color=auto'

      alias cdtmp='cd "$(mktemp -d)"'

      function take() {
        if [[ $# -ne 1 ]]; then
          echo "Usage: take <dir>"
          return 1
        fi
        mkdir "$1"
        cd "$1"
      }

      function rl() {
        local mypath
        if echo "$1" | grep -qE "^/"; then
          mypath="$1"
        else
          if ! mypath=$(whence -p "$1"); then
            echo "Failed to find binary"
            return 1
          fi
        fi

        while [ -L "$mypath" ]; do
          echo "$mypath"
          mypath=$(readlink "$mypath")
        done

        echo "$mypath"
      }

      function ns() {
        nix-shell -p "$@"
      }

      function ns-unstable() {
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
      foot
      inputrc
      tmux
      yazi
      zsh
    ];
  };
}
