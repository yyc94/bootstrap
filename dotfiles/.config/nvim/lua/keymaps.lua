-- define common options
local opts = {
    noremap = true,      -- non-recursive
    silent = true,       -- do not show message
}
local map = vim.api.nvim_set_keymap
----------------
-- Leader Map --
----------------
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
-----------------
-- Normal mode --
-----------------
-- Basic --
vim.keymap.set('n', '<A-q>', '<Cmd>wq<Cr>', opts)
vim.keymap.set('n', '<A-s>', '<Cmd>w<Cr>', opts)
vim.keymap.set('n', '<Tab>q', '<Cmd>q<Cr>', opts)
vim.keymap.set('n', 'U', '<C-r>', opts)
-- Fuck Dell --
-- vim.keymap.set('n', '<PageUp>', '<Up>', opts)
-- vim.keymap.set('n', '<PageDown>', '<Down>', opts)
-- vim.keymap.set('i', '<PageUp>', '<Up>', opts)
-- vim.keymap.set('i', '<PageDown>', '<Down>', opts)

vim.keymap.set('n', '\'\'','<C-O>', opts)

-- Hint: see `:h vim.map.set()`
-- Better window navigation
vim.keymap.set('n', '<C-h>', '<C-w>h', opts)
vim.keymap.set('n', '<C-j>', '<C-w>j', opts)
vim.keymap.set('n', '<C-k>', '<C-w>k', opts)
vim.keymap.set('n', '<C-l>', '<C-w>l', opts)

-- Resize with arrows
-- delta: 2 lines
vim.keymap.set('n', '<C-Up>', ':resize -2<CR>', opts)
vim.keymap.set('n', '<C-Down>', ':resize +2<CR>', opts)
vim.keymap.set('n', '<C-Left>', ':vertical resize -2<CR>', opts)
vim.keymap.set('n', '<C-Right>', ':vertical resize +2<CR>', opts)


-- Hint: start visual mode with the same area as the previous area and the same mode
vim.keymap.set('v', '<', '<gv', opts)
vim.keymap.set('v', '>', '>gv', opts)

---------------
-- Telescope --
---------------
map("n", "<leader>ff", "<Cmd>Telescope find_files<CR>", opts)
map("n", "<leader>fg", "<Cmd>Telescope live_grep<CR>", opts)
map("n", "<leader>fh", "<Cmd>Telescope help_tags<CR>", opts)
map("n", "<leader>fb", "<Cmd>Telescope buffers<CR>", opts)
map("n", "<leader>fd", "<Cmd>Telescope lsp_definitions<CR>", opts)
map("n", "<leader>fc", "<Cmd>Telescope lsp_incoming_calls<CR>", opts)
map("n", "<leader>fr", "<Cmd>Telescope lsp_references<CR>", opts)
map("n", "<leader>ft", "<Cmd>Telescope lsp_type_definitions<CR>", opts)
map("n", "<leader>fi", "<Cmd>Telescope lsp_implementations<CR>", opts)
map("n", "<leader>fs", "<Cmd>Telescope lsp_workspace_symbols<CR>", opts)
map("n", "<leader>fp", "<Cmd>Telescope projects<CR>", opts)

---------
-- Hop --
---------
map("n", "E", "<Cmd>HopChar1<CR>", opts)

---------------------
-- Symbols Outline --
---------------------
-- map("n", "<C-o>", "<Cmd>SymbolsOutline<Cr>", opts)
-- map("n", "<C-o>", "<Cmd>AerialToggle<Cr>", opts)
-- vim.keymap.set("n", "<C-o>", "<cmd>AerialToggle!<CR>")

---------------
-- Nvim Tree --
---------------
map("n", '<A-m>', "<CMD>NvimTreeToggle<CR>", opts)

----------------
-- Bufferline --
----------------
map("n", '<leader><Tab>', "<CMD>BufferLineCycleNext<CR>", opts)
map("n", '<leader><S-Tab>', "<CMD>BufferLineCyclePrev<CR>", opts)

--------------
-- Zen Mode --
--------------
map("n", '<leader>z', "<CMD>ZenMode<CR>", opts)

--------------
-- Copilot  --
--------------

vim.keymap.set('i', '<F10>', 'copilot#Accept("\\<CR>")', {
    expr = true,
    replace_keycodes = false
})
vim.g.copilot_no_tab_map = true

-------------
-- Flowterm --
-------------
vim.keymap.set('n', '<Leader>tt', "<cmd>FloatermToggle<CR>", {noremap=true})
vim.keymap.set('t', '<Leader>tt', "<C-\\><C-n><cmd>FloatermToggle<CR>", {noremap=true})

-------------
-- Preview --
-------------
vim.keymap.set('n', '<Leader>gd',"<cmd>lua require('goto-preview').goto_preview_definition()<CR>", {noremap=true})
vim.keymap.set('n', '<Leader>gt',"<cmd>lua require('goto-preview').goto_preview_type_definition()<CR>", {noremap=true})
vim.keymap.set('n', '<Leader>gi',"<cmd>lua require('goto-preview').goto_preview_implementation()<CR>", {noremap=true})
vim.keymap.set('n', '<Leader>gD',"<cmd>lua require('goto-preview').goto_preview_declaration()<CR>", {noremap=true})
vim.keymap.set('n', '<Leader>gP',"<cmd>lua require('goto-preview').close_all_win()<CR>", {noremap=true})
vim.keymap.set('n', '<Leader>gr',"<cmd>lua require('goto-preview').goto_preview_references()<CR>", {noremap=true})

vim.keymap.set('n', '<Leader>ee', "<cmd>%s/\\s\\+$//e<CR>", {noremap = true, desc = "clear all blanks at the end of lines"})

vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = {
        "*.c", "*.cpp", "*.cc", "*.h", "*.hpp", "*.inl", "*.lua", "*.rs", "Makefile", "makefile", "*.md"
    },
    callback = function()
        vim.cmd("%s/\\s\\+$//e")
    end,
    desc = "Clear all blanks at the end of each line when exit"
})
