-- LSP binds
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, {})
vim.keymap.set("n", "<leader>a", vim.lsp.buf.code_action, {})
vim.keymap.set("n", "<leader>i", vim.lsp.buf.hover, {})
vim.keymap.set("n", "<leader>f", vim.lsp.buf.format, {}) vim.keymap.set("n", "<leader>r", vim.lsp.buf.rename, {})

vim.keymap.set("n", "gd", vim.lsp.buf.definition, {})
vim.keymap.set("n", "gi", vim.lsp.buf.implementation, {})
vim.keymap.set("n", "gr", vim.lsp.buf.references, {})

-- Navigation binds
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")
vim.keymap.set("n", "<C-l>", "<C-w>l")

-- Split
vim.keymap.set("n", "<C-w>a", "<C-w>v")

-- Buffer management (tabs)
vim.keymap.set("n", "<leader>t", "<cmd>enew<cr>")
vim.keymap.set("n", "<TAB>", "<cmd>bnext<cr>")
vim.keymap.set("n", "<S-TAB>", "<cmd>bprevious<cr>")
vim.keymap.set("n", "<leader>d", "<cmd>bdelete<cr>")
vim.keymap.set("n", "<leader>b", "<cmd>BufferLinePick<cr>")

-- Misc
vim.keymap.set("n", "<leader>c", function()
  vim.fn.setreg("+", vim.fn.expand("%:~:.") .. ":" .. vim.fn.line(".") .. ":" .. vim.fn.col("."))
end, { noremap = true, silent = true, desc = "Copy file path, line, and column" })

vim.keymap.set("n", "<leader>C", function()
  local clipboard_content = vim.fn.getreg('+')

  if not clipboard_content or clipboard_content == '' then
    vim.notify("Clipboard is empty", vim.log.levels.WARN)
    return
  end

  local pattern = "^(.*):(%d+):(%d+)$"
  local file_path, line_str, col_str = string.match(clipboard_content, pattern)

  if not file_path then
    pattern = "^(.*):(%d+)$"
    file_path, line_str = string.match(clipboard_content, pattern)
    col_str = "1"
  end

  if not file_path then
    file_path = clipboard_content
    line_str = "1"
    col_str = "1"
  end

  local line = tonumber(line_str) or 1
  local col = tonumber(col_str) or 1

  local file = io.open(file_path, "r")
  if not file then
    vim.notify("File not found: " .. file_path, vim.log.levels.ERROR)
    return
  end
  file:close()

  vim.cmd("edit " .. vim.fn.fnameescape(file_path))

  vim.cmd("normal! " .. line .. "G")
  vim.cmd("normal! " .. col .. "|")

  vim.notify("Opened " .. file_path .. " at line " .. line .. ", column " .. col, vim.log.levels.INFO)
end, { noremap = true, silent = true, desc = "Go to path, line, and column in clipboard" })

local function grepbuf(pattern)
  if not pattern or pattern == "" then
    vim.notify("GrepBuf: pattern required", vim.log.levels.ERROR)
    return
  end

  local result = vim.system(
    { "rg", "--vimgrep", "--no-heading", pattern },
    { text = true }
  ):wait()

  local lines
  if result.stdout and result.stdout ~= "" then
    -- rg --vimgrep outputs filepath:row:col:match, trim to filepath:row:col
    lines = {}
    for line in result.stdout:gmatch("[^\n]+") do
      local filepath, row, col, match = line:match("^(.+):(%d+):(%d+):(.*)")
      if filepath then
        table.insert(lines, filepath .. ":" .. row .. ":" .. col .. " " .. match:match("^%s*(.*)"))
      end
    end
  else
    lines = { "(no results)" }
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  -- vim.bo[buf].modifiable = false
  vim.api.nvim_set_current_buf(buf)
end

vim.api.nvim_create_user_command("GrepBuf", function(opts)
  grepbuf(opts.args)
end, { nargs = 1, desc = "Grep codebase with ripgrep into a new buffer" })
