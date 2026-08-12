require("trouble").setup({})

vim.keymap.set("n", "<leader>x", "<cmd>Trouble diagnostics toggle<cr>",
  { desc = "Diagnostics (Trouble)" })
vim.keymap.set("n", "<leader>X", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
  { desc = "Buffer Diagnostics (Trouble)" })
