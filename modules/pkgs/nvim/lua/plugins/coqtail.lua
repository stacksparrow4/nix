vim.g.coqtail_nomap = 1

local mappings = {
  { lhs = "<leader>j", rhs = "<Plug>RocqNext" },
  { lhs = "<leader>k", rhs = "<Plug>RocqUndo" },
  { lhs = "<leader>l", rhs = "<Plug>RocqToLine" },
  { lhs = "<leader>cc", rhs = "<Plug>RocqStart" },
}

vim.api.nvim_create_autocmd("FileType", {
  pattern = "coq",
  callback = function(args)
    for _, map in ipairs(mappings) do
      vim.keymap.set("n", map.lhs, map.rhs, { buffer = args.buf, silent = true })
    end
  end,
})
