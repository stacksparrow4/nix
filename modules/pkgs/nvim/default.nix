{ config, ... }:

let
  globalConfig = config;
in
{
  perSystem =
    {
      pkgs,
      pkgsLinux,
      config,
      lib,
      inputs',
      ...
    }:
    let
      sprrwConfig = pkgsLinux.vimUtils.buildVimPlugin {
        pname = "sprrw-nvim-config";
        version = "0.1.0";
        doCheck = false;
        src = pkgs.runCommand "sprrw-nvim-config-src" { } ''
          mkdir -p $out/lua
          cp -r ${./lua}/. $out/lua/
        '';
      };

      mkNvim =
        {
          pkgs,
          additionalPlugins ? [ ],
          additionalLua ? "",
        }:
        (pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped {
          wrapRc = true;

          withPython3 = false;
          withRuby = false;

          luaRcContent = ''
            require("config")
            require("plugins")
            require("lsps")
            require("keymaps")
          ''
          + "\n"
          + additionalLua;

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
                # General
                globalConfig.flake.packages.${pkgs.stdenv.hostPlatform.system}.yazi
                # Python
                basedpyright
                ruff
                # Nix
                nixd
                nixfmt
                # C
                gcc
                # Rust
                cargo
                rustc
                clippy
                rust-analyzer
                rustfmt
                # JS
                typescript-language-server
                # Typst
                tinymist
                typstyle
              ]
            )}"
          ];

          plugins = [
            sprrwConfig
          ]
          ++ (
            with pkgs.vimPlugins;
            [
              inputs'.blink-cmp.packages.default
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
              inputs'.nvim-http-client.packages.default
            ]
            ++ additionalPlugins
          )
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
        })
        // {
          configure = args: mkNvim ({ inherit pkgs; } // args);
        };

      mkNvimBoxed =
        { nvim-unboxed }:
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
        // {
          configure =
            args:
            mkNvimBoxed {
              nvim-unboxed = mkNvim (
                {
                  inherit pkgs;
                }
                // args
              );
            };
        };
    in
    {
      packages = {
        nvim-unboxed = mkNvim { inherit pkgs; };
        nvim = mkNvimBoxed {
          nvim-unboxed = mkNvim { pkgs = pkgsLinux; };
        };
      };
    };
}
