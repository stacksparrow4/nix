{ inputs, ... }:

{
  perSystem =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      sprrwConfig = pkgs.vimUtils.buildVimPlugin {
        pname = "sprrw-nvim-config";
        version = "0.1.0";
        doCheck = false;
        src = pkgs.runCommand "sprrw-nvim-config-src" { } ''
          mkdir -p $out/lua
          cp -r ${./lua}/. $out/lua/
        '';
      };

      nvim-unboxed = pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped {
        wrapRc = true;

        withPython3 = false;
        withRuby = false;

        luaRcContent = ''
          require("config")
          require("plugins")
          require("lsps")
          require("keymaps")
        '';

        wrapperArgs = [
          # Some treesitter parsers need this library
          "--suffix"
          "LD_LIBRARY_PATH"
          ":"
          "${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}"
          "--suffix"
          "PATH"
          ":"
          "${lib.makeBinPath (
            with pkgs;
            [
              basedpyright
              ruff
              nixd
              nixfmt
              gcc
              config.packages.yazi
            ]
          )}"
        ];

        plugins =
          [ sprrwConfig ]
          ++ (with pkgs.vimPlugins; [
            blink-cmp
            bufferline-nvim
            friendly-snippets
            gitsigns-nvim
            img-clip-nvim
            tokyonight-nvim
            nvim-lspconfig
            nvim-treesitter
            nvim-web-devicons
            plenary-nvim
            snacks-nvim
            telescope-fzf-native-nvim
            telescope-nvim
            typst-preview-nvim
            yazi-nvim
            trouble-nvim
            conform-nvim
            (inputs.nvim-http-client.packages."${pkgs.stdenv.hostPlatform.system}".default)
          ])
          ++ (with pkgs.vimPlugins.nvim-treesitter-parsers; [
            lua
            nix
            c
            cpp
            cmake
            vim
            vimdoc
            python
            rust
            go
            yaml
            json
            toml
            javascript
            typescript
            markdown
            typst
            java
            javadoc
            c_sharp
            caddy
            nginx
            ruby
          ]);
      };
    in
    {
      packages = {
        inherit nvim-unboxed;
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        nvim = pkgs.symlinkJoin {
          name = "nvim";
          paths = [
            (pkgs.writeShellApplication {
              name = "nvim";
              text = ''
                if [[ "''${IN_SPRRW_SANDBOX:-}" == 1 ]]; then
                  ${nvim-unboxed}/bin/nvim "$@"
                else
                  share_dir="$(pwd)"
                  vim_args=()
                  if [[ $# -eq 1 ]] && [[ "$1" == /* ]]; then
                    arg="$1"
                    if [[ -d "$arg" ]]; then
                      share_dir="$arg"
                      share_file="."
                    else
                      share_dir=$(dirname "$arg")
                      share_file=$(basename "$arg")
                    fi
                    vim_args+=("$share_file")
                  else
                    vim_args+=("$@")
                  fi

                  (cd "$share_dir" && ${config.packages.box}/bin/box --cwd --wayland --ro-git -- ${nvim-unboxed}/bin/nvim "''${vim_args[@]}")
                fi
              '';
            })
            (pkgs.runCommand "nvim-unsandboxed" { } ''
              mkdir -p $out/bin
              ln -s ${nvim-unboxed}/bin/nvim $out/bin/nvim-unsandboxed
            '')
          ];
        };
      };
    };
}
