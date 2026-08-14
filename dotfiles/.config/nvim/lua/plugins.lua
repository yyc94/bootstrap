local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", -- latest stable release
        lazypath,
    })
end

vim.opt.rtp:prepend(lazypath)
require("lazy").setup({
    -- theme
    {
        --'sainnhe/everforest',
        -- 'sainnhe/gruvbox-material',
        --'sainnhe/gruvbox',
        'sainnhe/sonokai',
        lazy = false,
        priority = 1000,
        config = function()
            -- Optionally configure and load the colorscheme
            -- directly inside the plugin declaration.
            -- vim.g.everforest_enable_italic = true
            -- vim.cmd.colorscheme('everforest')
            -- vim.cmd.colorscheme('gruvbox-material')
            vim.g.sonokai_enable_italic = true
            vim.cmd.colorscheme('sonokai')
        end
    },
    {
        "onsails/lspkind.nvim",
        event = { "VimEnter" },
    }, -- Auto-completion engine
    {
        "hrsh7th/nvim-cmp",
        dependencies = {
            "lspkind.nvim",
            "hrsh7th/cmp-nvim-lsp", -- lsp auto-completion
            "hrsh7th/cmp-buffer", -- buffer auto-completion
            "hrsh7th/cmp-path", -- path auto-completion
            "hrsh7th/cmp-cmdline", -- cmdline auto-completion
        },
        config = function()
            require("config.nvim-cmp")
        end,
    },
    -- copilot
    -- {
    --     "github/copilot.vim"
    -- },
    -- Code snippet engine
    {
        "L3MON4D3/LuaSnip",
        version = "v2.*",
    },
    -- LSP manager
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
    "neovim/nvim-lspconfig",
    -- Others
    {
        "nvim-treesitter/nvim-treesitter",
        run = ':TSUpdate',
        config = function()
            require('config.nvim-treesitter')
        end
    },
    {
        "voldikss/vim-floaterm",
    },
    {
        "nvim-telescope/telescope.nvim",
        tag = 'v0.2.1',
        dependencies = {
            'nvim-lua/plenary.nvim',
            {
                "nvim-telescope/telescope-live-grep-args.nvim",
                version = "^1.0.0",
            },
            -- 添加 fd 作为依赖（推荐）
            "sharkdp/fd",
        },
        config = function()
            local telescope = require("telescope")
            telescope.setup({
                defaults = {
                    file_ignore_patterns = { ".git/", "node_modules/" }, -- 忽略的目录
                    hidden = true, -- 显示隐藏文件
                    cwd = vim.fn.getcwd(),
                    vimgrep_arguments = {
                        "rg",
                        "--color=never",
                        "--no-heading",
                        "--with-filename",
                        "--line-number",
                        "--column",
                        "--smart-case",
                        "--no-ignore",  -- 关键参数：忽略 .gitignore
                        "--hidden",     -- 同时搜索隐藏文件
                    },
                },
                pickers = {
                    find_files = {
                        find_command = {
                            "rg",
                            "--files",
                            "--hidden",
                            "--glob", "!.git",
                            "--no-ignore",
                        },
                    },
                },
            })
            telescope.load_extension("live_grep_args")
        end
    },
    {
        "phaazon/hop.nvim",
        config = function()
            require('hop').setup({})
        end
    },
    {
        "kyazdani42/nvim-tree.lua",
        requires = 'kyazdani42/nvim-web-devicons',
        config = function ()
            require('config.nvim-tree')
        end
    },
    {
        "folke/todo-comments.nvim",
        config = function ()
            require('config.todo-comments')
        end
    },
    {
        "folke/trouble.nvim",
        config = function ()
            require('config.trouble')
        end
    },
    "burntsushi/ripgrep",
    {
        "SmiteshP/nvim-navbuddy",
        dependencies = {
            "neovim/nvim-lspconfig",
            "SmiteshP/nvim-navic",
            "MunifTanjim/nui.nvim",
            "kyazdani42/nvim-web-devicons",
        },
        config = function()
            require("config.nvim-navbuddy").config()  -- 加载上述配置
        end,
        -- 延迟加载
        event = "LspAttach",
        keys = {
            { "<C-o>", desc = "Navbuddy" }
        }
    },
    {
        "akinsho/bufferline.nvim",
        requires = "kyazdani42/nvim-web-devicons",
        config = function()
            require('config.bufferline')
        end
    },
    {
        'windwp/nvim-autopairs',
        event = "InsertEnter",
        config = true
    },
    {
        "terrortylor/nvim-comment",
        dependencies = {"JoosepAlviste/nvim-ts-context-commentstring"},
        config = function ()
            require('nvim_comment').setup {
                hook = function()
                    require('ts_context_commentstring').update_commentstring()
                end,
            }
        end
    },
    {
        "JoosepAlviste/nvim-ts-context-commentstring",
    },
    {
        "gen740/SmoothCursor.nvim",
        config = function ()
            require('smoothcursor').setup()
        end
    },
    {
        "folke/zen-mode.nvim",
        opts = {
            -- your configuration comes here
            -- or leave it empty to use the default settings
            -- refer to the configuration section below
        }
    },
    {
        'nvimdev/dashboard-nvim',
        event = 'VimEnter',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        config = function()
            require('dashboard').setup {
                theme = 'hyper',
                disable_move = true,
                shortcut_type = 'number',
                shuffle_letter = false,
                letter_list = 'abcdefghilmnopqrstuvwxyz',
                buffer_name = 'Dashboard',
                change_to_vcs_root = false,
                config = {
                    header = {
                        '█████╗ ██████╗ ███████╗    ██╗   ██╗ ██████╗ ██╗   ██╗    ███████╗ ██████╗ ██████╗ ███████╗██████╗ ██████╗ ',
                        '██╔══██╗██╔══██╗██╔════╝    ╚██╗ ██╔╝██╔═══██╗██║   ██║    ██╔════╝██╔═══██╗██╔══██╗██╔════╝██╔══██╗╚════██╗',
                        '███████║██████╔╝█████╗       ╚████╔╝ ██║   ██║██║   ██║    ███████╗██║   ██║██████╔╝█████╗  ██████╔╝  ▄███╔╝',
                        '██╔══██║██╔══██╗██╔══╝        ╚██╔╝  ██║   ██║██║   ██║    ╚════██║██║   ██║██╔══██╗██╔══╝  ██╔══██╗  ▀▀══╝',
                        '██║  ██║██║  ██║███████╗       ██║   ╚██████╔╝╚██████╔╝    ███████║╚██████╔╝██████╔╝███████╗██║  ██║  ██╗  ',
                        '╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝       ╚═╝    ╚═════╝  ╚═════╝     ╚══════╝ ╚═════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝  ╚═╝',
                        '                                                                                                ',
                    },
                    week_header = {
                        enable = false,
                        concat = nil,
                        append = nil,
                    },
                    shortcut = {
                        {
                            desc = '󰚰 Update',
                            action = 'Lazy update',
                            key = 'u'
                        },
                        {
                            desc = ' Files',
                            action = 'Telescope find_files',
                            key = 'f',
                        },
                        {
                            desc = ' Projects',
                            action = 'Telescope projects',
                            key = 'p',
                        },
                        {
                            desc = ' Profile',
                            action = 'Triforce profile',
                            key = 'l',
                        },
                        {
                            desc = ' Search',
                            action = 'Telescope live_grep',
                            key = 's',
                        },
                        {
                            desc = '󰈆 Todo',
                            action = 'Org agenda a',
                            key = 't',
                        },
                        {
                            desc = '󰈆 Quit',
                            action = 'quit',
                            key = 'q',
                        },
                    },
                    footer = {
                        '',
                        '',
                        '',
                        'You started a job',
                        'that you hate when you\'re sober',
                        'and hate even more when you\'re not',
                    },
                },
                hide = {
                    statusline = true,
                    tabline = true,
                },
                preview = {
                    command = '',
                    file_path = nil,
                    file_height = 0,
                    file_width = 0,
                },
                directories = {
                    { key = 'p', path = '~/Projects/' },
                    { key = 'e', path = '~/.config/nvim' },
                },
            }
        end
    },
    {
        'ahmedkhalf/project.nvim',
        config = function()
            require("project_nvim").setup({
                detection_methods = {"pattern"},
                patterns = {".git", "Makefile", "package.json"},
                datapath = vim.fn.stdpath("data"),
                sync_root_with_cwd = true,
                update_cwd = true,
                update_focused_file = {
                    enable = true,
                    update_cwd = true,
                },
            })
            require("telescope").load_extension("projects")
        end,
    },
    {
        "chentoast/marks.nvim",
        event = "VeryLazy",
        opts = {},
    },
    {
        "kevinhwang91/nvim-ufo",
        event = "BufRead",
        dependencies = {
            { "kevinhwang91/promise-async" },
            {
                "luukvbaal/statuscol.nvim",
                config = function()
                    local builtin = require("statuscol.builtin")
                    require("statuscol").setup({
                        -- foldfunc = "builtin",
                        -- setopt = true,
                        relculright = true,
                        segments = {
                            { text = { builtin.foldfunc }, click = "v:lua.ScFa" },
                            { text = { "%s" }, click = "v:lua.ScSa" },
                            { text = { builtin.lnumfunc, " " }, click = "v:lua.ScLa" },
                        },
                    })
                end,
            },
        },
        config = function()
            -- Fold options
            vim.o.fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]]
            vim.o.foldcolumn = "1" -- '0' is not bad
            vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
            vim.o.foldlevelstart = 99
            vim.o.foldenable = true

            local handler = function(virtText, lnum, endLnum, width, truncate)
                local newVirtText = {}
                local suffix = (' 󰁂 %d '):format(endLnum - lnum)
                local sufWidth = vim.fn.strdisplaywidth(suffix)
                local targetWidth = width - sufWidth
                local curWidth = 0
                for _, chunk in ipairs(virtText) do
                    local chunkText = chunk[1]
                    local chunkWidth = vim.fn.strdisplaywidth(chunkText)
                    if targetWidth > curWidth + chunkWidth then
                        table.insert(newVirtText, chunk)
                    else
                        chunkText = truncate(chunkText, targetWidth - curWidth)
                        local hlGroup = chunk[2]
                        table.insert(newVirtText, {chunkText, hlGroup})
                        chunkWidth = vim.fn.strdisplaywidth(chunkText)
                        -- str width returned from truncate() may less than 2nd argument, need padding
                        if curWidth + chunkWidth < targetWidth then
                            suffix = suffix .. (' '):rep(targetWidth - curWidth - chunkWidth)
                        end
                        break
                    end
                    curWidth = curWidth + chunkWidth
                end
                table.insert(newVirtText, {suffix, 'MoreMsg'})
                return newVirtText
            end
            require("ufo").setup({
                fold_virt_text_handler = handler,
                provider_selector = function(bufnr, filetype, buftype)
                    return {'treesitter', 'indent'}
                end
            })
        end,
    },
    {
        "danymat/neogen",
        config = function()
            require('neogen').setup {
                languages = {
                    c = {
                        template = {
                            annotation_convention = "doxygen"
                        }
                    },
                    cpp = {
                        template = {
                            annotation_convention = "doxygen"
                        }
                    },
                }
            }
        end,
    },
    {
        "lewis6991/hover.nvim",
        config = function()
            require("hover").setup({
                init = function()
                    require("hover.providers.lsp")
                end,
                preview_opts = {
                    border = 'rounded'
                },
                providers = {
                    "lsp",
                },
                title = false
            })
            vim.keymap.set("n", "K", require("hover").hover, {desc = "hover.nvim"})
            vim.keymap.set("n", "gK", require("hover").hover_select, {desc = "hover.nvim (select)"})
        end
    },
    -- {
    --     "bngarren/checkmate.nvim",
    --     ft = "markdown", -- Lazy loads for Markdown files matching patterns in 'files'
    --     opts = {
    --         todo_markers = {
    --            unchecked = "󰄰 ",
    --            checked = "󰄴 ",
    --         },
    --     },
    -- },
    -- {
    --     "xiyaowong/nvim-transparent",
    -- },
    {
        "rmagatti/goto-preview",
        dependencies = { "rmagatti/logger.nvim" },
        event = "BufEnter",
        config = true,
    },
    {
        'alanfortlink/blackjack.nvim',
        dependencies = { 'nvim-lua/plenary.nvim' },
        config = function ()
            require("blackjack").setup({
                card_style = "mini", -- Can be "mini" or "large".
                suit_style = "black", -- Can be "black" or "white".
                scores_path = "/home/yangyuchen/.others/blackjack_scores.json", -- Default location to store the scores.json file.
                keybindings = {
                    ["next"] = "j",
                    ["finish"] = "k",
                    ["quit"] = "q",
                },
            })
        end
    },
    -- {
    --     "kawre/leetcode.nvim",
    --     build = ":TSUpdate html", -- if you have `nvim-treesitter` installed
    --     dependencies = {
    --         "nvim-telescope/telescope.nvim",
    --         -- "ibhagwan/fzf-lua",
    --         "nvim-lua/plenary.nvim",
    --         "MunifTanjim/nui.nvim",
    --     },
    --     opts = {
    --         cn = {
    --             enabled = true,
    --             translator = true,
    --             translate_problems = true,
    --         },
    --     },
    -- },
    {
        "lewis6991/gitsigns.nvim",
        opts = {
            signs = {
                add = { text = "+" },
                change = { text = "~" },
                delete = { text = "_" },
            },
        },
    },
    {
        "HiPhish/rainbow-delimiters.nvim",
    },
    {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        ---@module "ibl"
        ---@type ibl.config
        opts = {
            -- 禁用缩进线的文件类型
            exclude = {
                filetypes = {
                    "alpha",       -- alpha-nvim 的 Dashboard
                    "dashboard",   -- dashboard-nvim
                    "NvimTree",    -- 文件管理器（如果不需要）
                    "TelescopePrompt", -- Telescope 弹出窗口
                    "help",        -- 帮助文档
                },
                buftypes = {
                    "terminal",    -- 终端缓冲区
                    "nofile",     -- 无文件缓冲区（如 Dashboard）
                },
            },
        },
    },
    {
        'nvim-orgmode/orgmode',
        event = 'VeryLazy',
        ft = { 'org' },
        config = function()
            require('orgmode').setup({
                highlignt = {
                    enable = true,
                    inline_code = true,
                },
                org_agenda_files = '~/.orgfiles/**/*',
                org_default_notes_file = '~/.orgfiles/refile.org',
                org_todo_keywords = {'PENDING', 'WAITING', '|', 'COMPLETED', 'DELETED'},
                org_todo_keyword_faces = {
                    PENDING = ':foreground #00FA9A :weight bold',
                    WAITING = ':foreground #7FFFAA :weight bold :underline on',
                    COMPLETED = ':foreground #D3D3D3 :slant italic',
                    DELETED =':foreground #696969 :slant italic :underline on'
                },
                org_startup_folded = 'showeverything',
                org_hide_leading_stars = true,
                org_deadline_warning_days = 3,
                org_agenda_custom_commands = {
                    i = {
                        description = 'Ideas',
                        types = {
                            {
                                type = 'tags',
                                match = 'IDEA',
                                org_agenda_files = {'~/.orgfiles/IDEA/*.org'},
                                org_agenda_overriding_header = 'My ideas',
                            },
                        }
                    },
                },
                org_agenda_hide_empty_blocks = true,
                org_capture_templates = {
                    t = {
                        description = 'Task',
                        template = '* PENDING %?\n  %u',
                        target = '~/.orgfiles/TODO/todos.org'
                    },
                    i = {
                        description = 'Idea',
                        template = '* %<%Y-%m-%d> %<%A> :IDEA: \n* \n%?',
                        target = '~/.orgfiles/IDEA/%<%Y-%m>.org'
                    }
                },
                org_agenda_skip_scheduled_if_done = true,
                org_agenda_skip_deadline_if_done = true,
                mappings = {}
            })
        end,
    },
    {
        'gisketch/triforce.nvim',
        dependencies = { 'nvzone/volt' },
        config = function()
            require('triforce').setup({
                -- Optional: Add your configuration here
                keymap = {
                    show_profile = '<leader>tp', -- Open profile with <leader>tp
                },
            })
        end,
    },
    -- {
    --     "quentingruber/pomodoro.nvim",
    --     lazy = true, -- needed so the pomodoro can start at launch
    --     opts = {
    --         start_at_launch = true,
    --         work_duration = 25,
    --         break_duration = 5,
    --         delay_duration = 1, -- The additionnal work time you get when you delay a break
    --         long_break_duration = 15,
    --         breaks_before_long = 4,
    --         display_ui_on_break = true, -- Disable it if you only want to see the lualine
    --     },
    -- },
    {
        'code-biscuits/nvim-biscuits',
        dependencies = {
            'nvim-treesitter/nvim-treesitter',
        },
        config = function()
            require('nvim-biscuits').setup({
                on_events = { 'InsertLeave', 'CursorHoldI' },
                cursor_line_only = true,
                show_on_start = false,
                default_config = {
                    prefix_string = " 󱚠 ",
                },
            })
        end
    },
    {
        'nvim-lualine/lualine.nvim',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        -- optional = true,
        event = "VeryLazy",
        opts = function(_, opts)
            opts.sections = opts.sections or {}
            opts.sections.lualine_x = opts.sections.lualine_x or {}
            -- table.insert(opts.sections.lualine_x, 3, {
            --     function()
                    -- return require("pomodoro").get_pomodoro_status("🍅❌","🍅","☕")
                -- end,
            -- })
        end,
    },
    {
        "glyccogen/imprint.nvim",
        cmd = "Imprint",
        dependencies = {
            "nvim-tree/nvim-web-devicons", -- optional, for file icons in the titlebar
        },
        config = function()
            require("imprint").setup({
                line_numbers = false,
                background = "#FFFFFF",
            })
        end,
    },
    {
        'stevearc/conform.nvim',
        opts = {},
        config = function()
            require("conform").setup({
                formatters_by_ft = {
                    cpp = { "clang-format", lsp_format = "fallback" },
                },
            })
        end,
    },
    {
        'Mathijs-Bakker/godotdev.nvim',
        dependencies = { 'mfussenegger/nvim-dap', 'rcarriga/nvim-dap-ui', 'nvim-treesitter' },
        config = function()
            require("godotdev").setup({
                editor_host = "127.0.0.1", -- Godot editor host
                editor_port = 6005,        -- Godot LSP port
                debug_port = 6006,         -- Godot debugger port
                godot_path = "godot",      -- executable used by :GodotRun* and health checks
                csharp = false,             -- Enable C# Installation Support
                autostart_editor_server = false, -- opt-in: start a Neovim server automatically on setup
                -- formatter = "gdscript-formatter",    -- "gdscript-formatter" | "gdformat" | false
                formatter = false,    -- "gdscript-formatter" | "gdformat" | false
                formatter_cmd = nil,       -- string or argv list; default gdscript-formatter adds "--reorder-code"
                inline_hints = {
                    enabled = true,         -- enable Neovim inlay hints when the attached server supports them
                },
                run = {
                    console = {
                        enabled = false,       -- capture :GodotRun* output in Neovim; these runs are no longer detached
                        renderer = "buffer",   -- "buffer" | "float"
                        buffer = {
                            position = "bottom", -- "right" | "bottom" | "current"
                            size = 0.3,
                        },
                        float = {
                            width = 0.8,
                            height = 0.25,
                            border = "rounded",
                        },
                    },
                },
                scene_tree = {
                    buffer = {
                        position = "left",     -- "left" | "right"
                        size = 0.35,
                    },
                    icons = "nerdfont",      -- "nerdfont" | "ascii" | false | { generic = "...", script_suffix = "...", types = { Node2D = "..." } }
                    icon_colors = {
                        generic = { fg = "white" },
                        groups = {
                            White = { fg = "white" },
                            Grey = { fg = "grey" },
                            Blue = { fg = "blue" },
                            Red = { fg = "red" },
                            Green = { fg = "green" },
                            Purple = { fg = "magenta" },
                            Yellow = { fg = "gold" },
                        },
                    },
                },
                editor_server = {
                    address = nil,           -- nil uses the current server or the platform default
                    remove_stale_socket = true,
                },
                treesitter = {
                    auto_setup = true,       -- convenience default; disable if you manage nvim-treesitter yourself
                    ensure_installed = { "gdscript" },
                },
                docs = {
                    renderer = "float",      -- default: open docs in a floating window
                    fallback_renderer = "browser", -- nil | "browser" | "buffer"; browser is the only fetch-recovery fallback
                    missing_symbol_feedback = "message", -- "message" | "notify"
                    version = "stable",      -- e.g. "stable", "latest", "4.5"
                    language = "en",
                    source_ref = "master",   -- godot-docs git ref used for floating docs
                    source_base_url = nil,   -- optional override for raw docs source
                    timeout_ms = 10000,
                    cache = {
                        enabled = true,
                        max_entries = 64,
                    },
                    float = {
                        width = 0.8,
                        height = 0.8,
                        border = "rounded",
                    },
                    buffer = {
                        position = "right",    -- "right" | "bottom" | "current"
                        size = 0.4,
                    },
                },
            })
        end
    }
})
