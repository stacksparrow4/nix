return {
  {
    "nvim-treesitter/nvim-treesitter",
    -- The `main` branch is a rewrite with no `nvim-treesitter.configs` module.
    -- Parsers are managed by Nix and already live on the runtimepath, so we do
    -- not install anything here; we only start treesitter per buffer.
    lazy = false,
    config = function()
      -- Start with all folds open; otherwise foldlevel=0 closes every
      -- treesitter fold as soon as a buffer is opened.
      vim.o.foldlevelstart = 99

      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          local buf = args.buf
          local ft = vim.bo[buf].filetype
          local lang = vim.treesitter.language.get_lang(ft) or ft

          -- No parser available for this filetype -> nothing to do.
          if not pcall(vim.treesitter.start, buf, lang) then
            return
          end

          -- Treesitter-based folding and indentation.
          vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
          vim.wo[0][0].foldmethod = "expr"
          vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"

          -- https://github.com/nvim-treesitter/nvim-treesitter/issues/1573
          -- Python relies on the regex syntax engine, so keep it on alongside
          -- treesitter highlighting (the old `additional_vim_regex_highlighting`).
          if lang == "python" then
            vim.bo[buf].syntax = "on"
          end
        end,
      })
    end,
  },
}
