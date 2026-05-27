-- Line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- Tabs are 2 spaces
vim.opt.tabstop = 2
vim.opt.softtabstop = -1
vim.opt.shiftwidth = 0
vim.opt.expandtab = true

-- Indent where possible
vim.opt.autoindent = true

-- Split default to right and down rather than left and up
vim.opt.splitbelow = true
vim.opt.splitright = true

-- Disable line wrapping
vim.opt.wrap = false

-- But not for md or typst files!
local wrap_augroup = vim.api.nvim_create_augroup("Wrap Settings", { clear = true })
vim.api.nvim_create_autocmd('BufEnter', {
  pattern = {'*.md', '*.typ'},
  group = wrap_augroup,
  command = 'setlocal wrap'
})

vim.opt.spelllang = "en_au"

-- Enable spell checking for .typ and .md files with Australian English
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
  pattern = {"*.typ", "*.md"},
  callback = function()
    vim.opt_local.spell = true
  end,
})

-- Use system clipboard
vim.opt.clipboard = "unnamedplus"

-- Fix cursor to center of screen
vim.opt.scrolloff = 999

vim.opt.virtualedit = "block"

-- Show replacements (such as :%s/) in a preview
vim.opt.inccommand = "split"

-- Ignore casing in VIM commands (incl. autocomplete)
vim.opt.ignorecase = true

-- Allow full range of colours in terminal
vim.opt.termguicolors = true

-- Set leader key to space
vim.g.mapleader = " "

-- Signs
vim.diagnostic.config({
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "",
      [vim.diagnostic.severity.WARN] = "",
      [vim.diagnostic.severity.INFO] = "",
      [vim.diagnostic.severity.HINT] = "",
    },
  },
})

-- Searching
-- vim.opt.hlsearch = false
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
