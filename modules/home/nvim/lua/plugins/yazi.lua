return {
  {
    "mikavilpas/yazi.nvim",
    event = "VeryLazy",
    dependencies = {
      "folke/snacks.nvim"
    },
    keys = {
      {
        "<leader>o",
        mode = { "n", "v" },
        "<cmd>Yazi<cr>",
        desc = "Open yazi at the current file",
      }
    },
    opts = {
      open_for_directories = true,
      keymaps = {
        show_help = "<f1>",
      },
      floating_window_scaling_factor = 1,
      yazi_floating_window_border = "none",
    },
    init = function()
      -- More details: https://github.com/mikavilpas/yazi.nvim/issues/802
      -- vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
    end,
  },
}
