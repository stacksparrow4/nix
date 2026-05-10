return {
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup({
        on_attach = function(bufnr)
          local gs = require("gitsigns")
          local map = function(mode, lhs, rhs)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr })
          end
          map("n", "<leader>hp", function()
            local source_wrap = vim.wo.wrap
            gs.preview_hunk()
            vim.schedule(function()
              for _, win in ipairs(vim.api.nvim_list_wins()) do
                local cfg = vim.api.nvim_win_get_config(win)
                if cfg.relative ~= "" then
                  if source_wrap then
                    vim.wo[win].wrap = true
                    vim.wo[win].linebreak = true
                    vim.wo[win].breakindent = true
                    -- Recompute the window height to account for wrapped
                    -- lines; otherwise the bottom of the hunk gets clipped.
                    local buf = vim.api.nvim_win_get_buf(win)
                    local line_count = vim.api.nvim_buf_line_count(buf)
                    local text_height = vim.api.nvim_win_text_height(win, {
                      start_row = 0,
                      end_row = line_count - 1,
                    }).all
                    cfg.height = math.max(cfg.height, text_height)
                    vim.api.nvim_win_set_config(win, cfg)
                  end
                end
              end
            end)
          end)
          map("n", "<leader>hr", gs.reset_hunk)
        end,
      })
    end,
  }
}
