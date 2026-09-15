{ config, inputs, ... }:

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
              ++ lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.wl-clipboard
            )}"
          ];

          plugins = [
            (pkgs.vimUtils.buildVimPlugin {
              pname = "sprrw-nvim-config";
              version = "0.1.0";
              doCheck = false;
              src = pkgs.runCommand "sprrw-nvim-config-src" { } ''
                mkdir -p $out/lua
                cp -r ${./lua}/. $out/lua/
              '';
            })
          ]
          ++ (
            with pkgs.vimPlugins;
            [
              inputs'.blink-cmp.packages.default
              bufferline-nvim
              friendly-snippets
              gitsigns-nvim
              img-clip-nvim
              vim-moonfly-colors
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

      nvimWrapper =
        (
          (inputs.crate2nix.lib.tools { inherit pkgs; }).appliedCargoNix {
            name = "nvim-wrapper";
            src = ./wrapper;
          }
        ).rootCrate.build;

      clipShimLinux = globalConfig.flake.packages.${pkgsLinux.stdenv.hostPlatform.system}.clip-shim;

      mkNvimBoxed =
        { nvim-unboxed }:
        (pkgs.runCommand "nvim" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
          makeWrapper ${nvimWrapper}/bin/nvim $out/bin/nvim \
            --set SPRRW_NVIM ${nvim-unboxed}/bin/nvim \
            ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin "--set SPRRW_CLIP_SHIM ${clipShimLinux}/bin/sprrw-clip"} \
            --prefix PATH : ${lib.makeBinPath [ config.packages.box ]}
        '')
        // {
          configure =
            args:
            mkNvimBoxed {
              nvim-unboxed = mkNvim ({ pkgs = pkgsLinux; } // args);
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
