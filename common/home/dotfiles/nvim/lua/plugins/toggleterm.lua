return {
  {
    'akinsho/toggleterm.nvim',
    version = "*",
    config = function()
      local tt = require("toggleterm")
      tt.setup({
        shell = "bash"
      })

      vim.keymap.set("n", "<Leader>c", tt.toggle, {})

      function _G.set_terminal_keymaps()
        local opts = {buffer = 0}
        vim.keymap.set('t', '<esc>', [[<C-\><C-n>]], opts)
        vim.keymap.set('t', '<C-j>', [[<Cmd>wincmd j<CR>]], opts)
        vim.keymap.set('t', '<C-k>', [[<Cmd>wincmd k<CR>]], opts)
        vim.keymap.set('t', '<C-w>', [[<C-\><C-n><C-w>]], opts)
      end

      vim.cmd('autocmd! TermOpen term://* lua set_terminal_keymaps()')
    end
  }
}
