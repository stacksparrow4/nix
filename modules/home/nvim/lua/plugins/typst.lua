require("typst-preview").setup({
  debug = false,
  open_cmd = "",
  port = 9009,
  dependencies_bin = {
    ['tinymist'] = 'tinymist',
    ['websocat'] = nil
  },
})
