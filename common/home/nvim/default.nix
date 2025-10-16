{ pkgs, config, lib, ... }:

{
  options = {
    sprrw.nvim.enable = lib.mkEnableOption "nvim";
  };

  config = lib.mkIf config.sprrw.nvim.enable {
    # https://dev.to/anurag_pramanik/how-to-enable-undercurl-in-neovim-terminal-and-tmux-setup-guide-2ld7
    
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

    # TODO: is there some way of doing this so nvim doesnt have to throw errors/be restarted
    # This should be doable by symlinking to a derviation that uses `cp` with the preserve timestamps argument
    # home.activation.clearNeovimCache = lib.hm.dag.entryAfter ["writeBoundary"] ''
      # rm -rf ~/.cache/nvim/luac
    # '';
  };
}
