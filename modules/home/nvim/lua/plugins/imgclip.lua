require("img-clip").setup({
  default = {
    dir_path = "screenshots",
    prompt_for_file_name = false
  },
  filetypes = {
    typst = {
      template = [[
#figure(
  image("$FILE_PATH", width: 100%),
  caption: [$CURSOR],
)
      ]],
    },
  },
})

vim.keymap.set("n", "<leader>p", "<cmd>PasteImage<cr>",
  { desc = "Paste image from system clipboard" })
