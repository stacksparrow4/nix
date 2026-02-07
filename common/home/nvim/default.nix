{ pkgs, config, lib, ... }:

let
  cfg = config.sprrw.nvim;
in
{
  options.sprrw.nvim = {
    enable = lib.mkEnableOption "nvim";

    sandboxAdditionalDockerArgs = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      defaultEditor = true;

      extraPackages = with pkgs; [
        basedpyright
        ruff
        nixd
        gcc
      ];

      # Some treesitter parsers need this library
      extraWrapperArgs = [
        "--suffix"
        "LD_LIBRARY_PATH"
        ":"
        "${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}"
      ];

      plugins = (with pkgs.vimPlugins; [
        lazy-nvim
        blink-cmp
        bufferline-nvim
        friendly-snippets
        gitsigns-nvim
        img-clip-nvim
        kanagawa-nvim
        nvim-lspconfig
        nvim-treesitter
        nvim-treesitter-textobjects
        nvim-web-devicons
        plenary-nvim
        snacks-nvim
        telescope-fzf-native-nvim
        telescope-nvim
        typst-preview-nvim
        yazi-nvim
        trouble-nvim
      ]) ++ (with pkgs.vimPlugins.nvim-treesitter-parsers; [
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
      ]);

      extraLuaConfig = ''
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

    home.packages = lib.mkIf config.sprrw.sandboxing.enable [
      ( lib.hiPrio (pkgs.writeShellScriptBin "nvim" ''
        if [[ -f /.dockerenv ]]; then
          "${config.programs.neovim.finalPackage}/bin/nvim" "$@"
        else
          if [[ $# -eq 1 ]] && [[ "$1" == /* ]]; then
            share_dir=$(dirname "$1")
            share_file=$(realpath --relative-to="$share_dir" "$1")
            if [[ -z "$share_file" ]]; then
              exit 1;
            fi
            SHARE_DIR="$share_dir" "${config.sprrw.sandboxing.runDocker {
              beforeTargetArgs = (config.sprrw.sandboxing.recipes.dir_as_pwd_starter "$SHARE_DIR") + " "
                + config.sprrw.sandboxing.recipes.x11_forward + " "
                + cfg.sandboxAdditionalDockerArgs;
              afterTargetArgs = "${config.programs.neovim.finalPackage}/bin/nvim";
            }}" "$share_file"
          else
            "${config.sprrw.sandboxing.runDocker {
              beforeTargetArgs = config.sprrw.sandboxing.recipes.pwd_starter + " " + config.sprrw.sandboxing.recipes.x11_forward + " " + cfg.sandboxAdditionalDockerArgs;
              afterTargetArgs = "${config.programs.neovim.finalPackage}/bin/nvim";
            }}" "$@"
          fi
        fi
      '') )
      (pkgs.runCommand "nvim-unsandboxed" {} ''
        mkdir -p $out/bin
        ln -s ${config.programs.neovim.finalPackage}/bin/nvim $out/bin/nvim-unsandboxed
      '')
    ];
  };
}
