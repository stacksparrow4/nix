local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader><leader>', builtin.find_files, { desc = 'Telescope find files' })
vim.keymap.set('n', '<leader>g', builtin.live_grep, { desc = 'Telescope live grep' })
vim.keymap.set('n', '<leader>G', function()
  builtin.live_grep({ default_text = vim.fn.expand("<cword>") })
end, { desc = "Live grep current word" })

require("telescope").load_extension("fzf")
