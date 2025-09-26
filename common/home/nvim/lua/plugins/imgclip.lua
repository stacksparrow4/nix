return {
  {
    "HakonHarnes/img-clip.nvim",
    event = "VeryLazy",
    opts = {
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
    },
    keys = {
      { "<leader>p", "<cmd>PasteImage<cr>", desc = "Paste image from system clipboard" },
    },
  }
}
