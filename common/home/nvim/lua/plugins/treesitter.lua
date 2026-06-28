return {
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    config = function()
      vim.o.foldlevelstart = 99

      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          local buf = args.buf
          local ft = vim.bo[buf].filetype
          local lang = vim.treesitter.language.get_lang(ft) or ft

          if not pcall(vim.treesitter.start, buf, lang) then
            return
          end

          vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
          vim.wo[0][0].foldmethod = "expr"
          vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"

          if lang == "python" then
            vim.bo[buf].syntax = "on"
          end
        end,
      })
    end,
  },
}
