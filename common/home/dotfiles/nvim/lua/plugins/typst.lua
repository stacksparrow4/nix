return {
  {
    'chomosuke/typst-preview.nvim',
    lazy = false, -- or ft = 'typst'
    version = '1.*',
    opts = {
      debug = false,
      open_cmd = "nohup brave %s &>/dev/null",
      port = 9009,
      dependencies_bin = {
        ['tinymist'] = 'tinymist',
        ['websocat'] = nil
      },
    }, -- lazy.nvim will implicitly calls `setup {}`
  }
}
