return {
  {
    'chomosuke/typst-preview.nvim',
    lazy = false,
    version = '1.*',
    opts = {
      debug = false,
      open_cmd = "",
      port = 9009,
      dependencies_bin = {
        ['tinymist'] = 'tinymist',
        ['websocat'] = nil
      },
    },
  }
}
