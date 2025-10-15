return {
  {
    "rebelot/kanagawa.nvim",
    config = function()
      require("kanagawa").setup({
        commentStyle = { italic = false },
        keywordStyle = { italic = false },
        overrides = function()
          return {
            ["@variable.builtin"] = { italic = false },
          }
        end,
      })
      vim.cmd.colorscheme("kanagawa-dragon")
    end,
  },
}
