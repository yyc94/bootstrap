require('mason').setup({
    ui = {
        icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗"
        }
    }
})

require('mason-lspconfig').setup({
    ensure_installed = { 'clangd', 'pylsp', 'lua_ls', 'rust_analyzer' },
})

vim.diagnostic.config({
  virtual_text = {
    enabled = true,
    prefix = '●',
    severity_limit = 'Error'
  },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = {
    focusable = false,
    style = 'minimal',
    border = 'rounded',
    source = 'always',
  },
})

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.offsetEncoding = { "utf-8", "utf-16" }

local opts = { noremap = true, silent = true }
vim.keymap.set("n", "<space>e", vim.diagnostic.open_float, opts)
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
vim.keymap.set("n", "<space>q", vim.diagnostic.setloclist, opts)

local on_attach = function(client, bufnr)
	vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

	if client.name == "rust_analyzer" then
		vim.lsp.inlay_hint.enable(bufnr, true)
	end

	local bufopts = { noremap = true, silent = true, buffer = bufnr }
	vim.keymap.set("n", "gi", vim.lsp.buf.implementation, bufopts)
	vim.keymap.set("n", "<space>wa", vim.lsp.buf.add_workspace_folder, bufopts)
	vim.keymap.set("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, bufopts)
	vim.keymap.set("n", "<space>wl", function()
		print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
	end, bufopts)
	vim.keymap.set("n", "<space>D", vim.lsp.buf.type_definition, bufopts)
	vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, bufopts)
	vim.keymap.set("n", "<space>ca", vim.lsp.buf.code_action, bufopts)
	vim.keymap.set("n", "gr", vim.lsp.buf.references, bufopts)
	vim.keymap.set("n", "<space>f", function()
		vim.lsp.buf.format({
			async = true,
			filter = function(client)
				return client.name == "null-ls" or client.name == "hls"
			end,
		})
	end, bufopts)
end

local util = require('lspconfig.util')

local start_lsp = function(lsp_name, filetypes, custom_config)
  local config = vim.tbl_deep_extend('force', {
    name = lsp_name,
    capabilities = capabilities,
    on_attach = on_attach,
    root_dir = util.root_pattern('.git'),
  }, custom_config or {})

  vim.api.nvim_create_autocmd('FileType', {
    pattern = filetypes,
    callback = function()
      local root_dir = config.root_dir(vim.api.nvim_buf_get_name(0)) or vim.fn.getcwd()
      local launch_config = vim.tbl_deep_extend('force', {}, config, {
        root_dir = root_dir
      })
      -- config.root_dir = root_dir

      vim.lsp.start(launch_config)
    end,
    desc = string.format("Start %s LSP", lsp_name),
  })
end

start_lsp('pylsp', {'python'})
start_lsp('gopls', {'go', 'gomod', 'gowork', 'gotmpl'})
start_lsp('bashls', {'sh', 'bash'})
start_lsp('rust_analyzer', {'rust'}, {
  settings = {
    ['rust-analyzer'] = {
      cargo = { allFeatures = true },
      checkOnSave = {
        command = 'clippy',
      },
    },
  },
})
start_lsp('ocamllsp', {'ocaml', 'ocaml.interface', 'ocamllex'})
start_lsp('ruby_lsp', {'ruby'})
start_lsp('hls', {'haskell', 'lhaskell'})

start_lsp('lua_ls', {'lua'}, {
  cmd = {'lua-language-server'},
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      diagnostics = { globals = { "vim" } },
      workspace = { library = vim.api.nvim_get_runtime_file("", true) },
      telemetry = { enable = false },
    },
  },
  root_dir = util.root_pattern('.git', 'lua', '.luarc.json'),
})

start_lsp('clangd', {'c', 'cpp', 'objc', 'objcpp', 'cuda'}, {
  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy=false",
    "--header-insertion=iwyu",
    "--completion-style=detailed",
    "--function-arg-placeholders",
    "--all-scopes-completion",
    "--pch-storage=memory",
    "--pretty",
    "--limit-references=0",
    "--limit-workspace-search=0"
  },
  on_attach = function(client, bufnr)
    on_attach(client, bufnr)
    client.server_capabilities.diagnosticProvider = {
      interFileDependencies = true,
      workspaceDiagnostics = true
    }
    client.server_capabilities.documentFormattingProvider = false
  end,
  init_options = {
    fallbackFlags = { "-std=c++20", "--include-directory=./include" },
    cache = { directory = vim.fn.stdpath("cache") .. "/clangd" }
  },
  root_dir = util.root_pattern(
    "compile_commands.json",
    "compile_flags.txt",
    ".git",
    "CMakeLists.txt",
    "Makefile",
    ".clangd"
  ),
  single_file_support = true,
  flags = {
    debounce_text_changes = 150,
    allow_incremental_sync = true
  }
})
