-- LSP binds
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, {})
vim.keymap.set("n", "<leader>a", vim.lsp.buf.code_action, {})
vim.keymap.set("n", "<leader>i", vim.lsp.buf.hover, {})
vim.keymap.set("n", "<leader>f", vim.lsp.buf.format, {}) vim.keymap.set("n", "<leader>r", vim.lsp.buf.rename, {})

vim.keymap.set("n", "gd", vim.lsp.buf.definition, {})
vim.keymap.set("n", "gi", vim.lsp.buf.implementation, {})
vim.keymap.set("n", "gr", vim.lsp.buf.references, {})

-- Navigation binds
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")
vim.keymap.set("n", "<C-l>", "<C-w>l")

-- Split
vim.keymap.set("n", "<C-w>a", "<C-w>v")

-- Buffer management (tabs)
vim.keymap.set("n", "<leader>t", "<cmd>enew<cr>")
vim.keymap.set("n", "<TAB>", "<cmd>bnext<cr>")
vim.keymap.set("n", "<S-TAB>", "<cmd>bprevious<cr>")
vim.keymap.set("n", "<leader>d", "<cmd>bdelete<cr>")
vim.keymap.set("n", "<leader>b", "<cmd>BufferLinePick<cr>")

-- Misc
vim.keymap.set("n", "<leader>c", function()
  vim.fn.setreg("+", vim.fn.expand("%:p") .. ":" .. vim.fn.line(".") .. ":" .. vim.fn.col("."))
end, { noremap = true, silent = true, desc = "Copy file path, line, and column" })
