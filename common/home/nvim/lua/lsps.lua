vim.lsp.config.clangd = {}
vim.lsp.enable("clangd")
vim.lsp.config.nixd = {}
vim.lsp.enable("nixd")
vim.lsp.config.basedpyright = {}
vim.lsp.enable("basedpyright")
vim.lsp.config.ruff = {}
vim.lsp.enable("ruff")
vim.lsp.config.ts_ls = {}
vim.lsp.enable("ts_ls")
vim.lsp.config.rust_analyzer = {
  settings = {
    ['rust-analyzer'] = {
      cargo = {
        allFeatures = true,
      },
      procMacro = {
        enable = true,
      },
    },
  },
}
vim.lsp.enable("rust_analyzer")
vim.lsp.config.gopls = {}
vim.lsp.enable("gopls")
vim.lsp.config.tinymist = {
  settings = {
    formatterMode = "typstyle"
  }
}
vim.lsp.enable("tinymist")
vim.lsp.config.lemminx = {}
vim.lsp.enable("lemminx")
vim.lsp.config.cmake = {}
vim.lsp.enable("cmake")
vim.lsp.config.jdtls = {}
vim.lsp.enable("jdtls")

-- Setup Lua LSP for neovim dev
vim.lsp.config.lua_ls = {
  on_init = function(client)
    if client.workspace_folders then
      local path = client.workspace_folders[1].name
      if path ~= vim.fn.stdpath('config') and (vim.uv.fs_stat(path..'/.luarc.json') or vim.uv.fs_stat(path..'/.luarc.jsonc')) then
        return
      end
    end

    client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
      runtime = {
        -- Tell the language server which version of Lua you're using
        -- (most likely LuaJIT in the case of Neovim)
        version = 'LuaJIT'
      },
      -- Make the server aware of Neovim runtime files
      workspace = {
        checkThirdParty = false,
        library = {
          vim.env.VIMRUNTIME
          -- Depending on the usage, you might want to add additional paths here.
          -- "${3rd}/luv/library"
          -- "${3rd}/busted/library",
        }
        -- or pull in all of 'runtimepath'. NOTE: this is a lot slower and will cause issues when working on your own configuration (see https://github.com/neovim/nvim-vim.lsp.config/issues/3189)
        -- library = vim.api.nvim_get_runtime_file("", true)
      }
    })
  end,
  settings = {
    Lua = {}
  }
}
vim.lsp.enable("lua_ls")
