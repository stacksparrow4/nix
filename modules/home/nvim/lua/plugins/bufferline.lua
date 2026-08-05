return {
  {
    'akinsho/bufferline.nvim',
    version = "*",
    dependencies = 'nvim-tree/nvim-web-devicons',
    config = function ()
      require("bufferline").setup({
        options = {
          show_buffer_close_icons = false,
          show_close_icon = false
        },
        highlights = {
          buffer_selected = {
            italic = false,
          },
          diagnostic_selected = {
            italic = false,
          },
          hint_selected = {
            italic = false,
          },
          info_selected = {
            italic = false,
          },
          warning_selected = {
            italic = false,
          },
          error_selected = {
            italic = false,
          },
        },
      })
    end
  }
}
