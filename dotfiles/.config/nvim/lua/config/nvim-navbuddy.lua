local M = {}

function M.config()
  local navbuddy_ok, navbuddy = pcall(require, "nvim-navbuddy")
  if not navbuddy_ok then
    vim.notify("Navbuddy not found!", vim.log.levels.WARN)
    return
  end

  -- ========== 基础配置 ==========
  navbuddy.setup({
    window = {
      border = "single",       -- 窗口边框样式 (none, single, double, rounded, solid, shadow)
      size = "80%",            -- 窗口大小 (百分比或像素值 "600px")
      position = "50%",        -- 窗口位置 (百分比或 "left"/"right")
      sections = {
        left = {               -- 左侧面板配置
          size = "20%",
          border = nil,        -- 可单独设置边框
        },
        mid = {                -- 中间预览区
          size = "25%",
        },
        right = {              -- 右侧符号树
          border = nil,
          preview = "leaf"
        }
      }
    },
    node_markers = {
        enable = true,
        icons = {
            leaf = "   ",
            leaf_selected = " → ",
            branch = " ⤨ "
        },
    },
    icons = {
      File          = " ",
      Module        = " ",
      Namespace     = " ",
      Package       = " ",
      Class         = " ",
      Method        = " ",
      Property      = " ",
      Field         = " ",
      Constructor   = " ",
      Enum          = " ",
      Interface     = " ",
      Function      = "󰡱 ",
      Variable      = "󰫧 ",
      Constant      = " ",
      String        = " ",
      Number        = " ",
      Boolean       = "◩ ",
      Array         = " ",
      Object        = "⦿ ",
      Key           = " ",
      Null          = "󰟢 ",
      EnumMember    = " ",
      Struct        = " ",
      Event         = " ",
      Operator      = " ",
      TypeParameter = " ",
    },
    lsp = {
      auto_attach = true,      -- 自动附加到 LSP 客户端
      preference = nil,        -- LSP 服务器优先级列表 (如 { "pyright", "tsserver" })
    },
    source_buffer = {
      highlight = true,        -- 实时高亮对应代码
      reorient = "smart",      -- 窗口重定向策略 (smart, top, mid, none)
      scrolloff = nil          -- 滚动偏移量
    },
    -- 更多配置见 :h navbuddy-config
  })

  -- ========== 快捷键绑定 ==========
  local keymap = vim.keymap.set
  local opts = { noremap = true, silent = true }

  -- 主快捷键
  keymap("n", "<C-o>", "<cmd>Navbuddy<cr>", opts)

  -- 符号导航增强
  keymap("n", "<leader>nn", function()
    require("nvim-navbuddy").open()
    vim.cmd("wincmd =")  -- 自动平衡窗口
  end, { desc = "Open Navbuddy" })

  -- ========== LSP 集成 ==========
  -- 确保 navic 已设置 (用于面包屑导航)
  local navic_ok, navic = pcall(require, "nvim-navic")
  if navic_ok then
    navic.setup({
      icons = {
        -- 保持与 navbuddy 图标一致...
      }
    })

    -- 自动附加到 LSP 客户端
    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.supports_method("textDocument/documentSymbol") then
          navic.attach(client, args.buf)
        end
      end
    })
  end

  -- ========== UI 增强 ==========
  -- 自定义高亮组
  vim.api.nvim_set_hl(0, "NavbuddyName", { fg = "#7aa2f7", bold = true })
  vim.api.nvim_set_hl(0, "NavbuddyFloatBorder", { fg = "#7aa2f7", bg = "#1e2030" })

  -- 状态栏集成 (可选)
  vim.opt.winbar = "%{%v:lua.require'nvim-navic'.get_location()%}"
end

return M
