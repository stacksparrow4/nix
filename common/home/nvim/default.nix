{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:

let
  cfg = config.sprrw.nvim;
in
{
  options.sprrw.nvim = {
    enable = lib.mkEnableOption "nvim";

    sandboxed = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    additionalSharedFolders = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };

  config = lib.mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      defaultEditor = true;

      withPython3 = false;
      withRuby = false;

      extraPackages = with pkgs; [
        basedpyright
        ruff
        nixd
        nixfmt
        gcc
      ];

      # Some treesitter parsers need this library
      extraWrapperArgs = [
        "--suffix"
        "LD_LIBRARY_PATH"
        ":"
        "${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}"
      ];

      plugins =
        (with pkgs.vimPlugins; [
          lazy-nvim
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

      initLua = ''
        require("config")

        require("lazy").setup({
          performance = {
            reset_packpath = false,
            rtp = {
                reset = false,
              }
            },
          dev = {
            path = "${pkgs.vimUtils.packDir config.programs.neovim.finalPackage.passthru.packpathDirs}/pack/myNeovimPackages/start",
            patterns = {""}, -- Specify that all of our plugins will use the dev dir. Empty string is a wildcard!
          },
          install = {
            -- Safeguard in case we forget to install a plugin with Nix
            missing = false,
          },
          spec = {
            { import = "plugins" },
          },
          checker = { enabled = false },
        })

        require("keymaps")
      '';
    };

    xdg.configFile."nvim/lua" = {
      recursive = true;
      source = ./lua;
    };

    home.packages =
      let
        unsandboxed =
          pname:
          pkgs.runCommand pname { } ''
            mkdir -p $out/bin
            ln -s ${config.programs.neovim.finalPackage}/bin/nvim $out/bin/${pname}
          '';
        sandboxed =
          name:
          pkgs.writeShellApplication {
            inherit name;
            text =
              if cfg.sandboxed then
                ''
                  if [[ "''${IN_SPRRW_SANDBOX+x}" == 1 ]]; then
                    ${config.programs.neovim.finalPackage}/bin/nvim "$@"
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

                    (cd "$share_dir" && sandbox --cwd --wayland --ro-git ${
                      builtins.concatStringsSep " " (
                        map (sharedFolder: "-v \"${sharedFolder}:${sharedFolder}:ro\"") cfg.additionalSharedFolders
                      )
                    } -- ${config.programs.neovim.finalPackage}/bin/nvim "''${vim_args[@]}")
                  fi
                ''
              else
                ''
                  ${config.programs.neovim.finalPackage}/bin/nvim "$@"
                '';
          };
      in
      [
        (unsandboxed "nvim-unsandboxed")
        (unsandboxed "vim-unsandboxed")
        (unsandboxed "vi-unsandboxed")
        (sandboxed "bvim")
        (lib.hiPrio (sandboxed "nvim"))
        (lib.hiPrio (sandboxed "vim"))
        (lib.hiPrio (sandboxed "vi"))
      ];

    sprrw.term.shellExtra = ''
      # Necessary because of nix path order
      alias vi='nvim'
      alias vim='nvim'
    '';
  };
}
