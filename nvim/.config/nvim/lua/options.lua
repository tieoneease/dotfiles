-- disable netrw at the very start of your init.lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- scrolling and line nums
vim.opt.number = true
vim.opt.scrolloff = 10

-- indents
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true

-- Text wrapping configuration 
vim.opt.wrap = true  -- Enable line wrapping
vim.opt.linebreak = true  -- Break lines at word boundaries
vim.opt.breakindent = true  -- Preserve indentation in wrapped lines
vim.opt.showbreak = "↪ "  -- Show a nice symbol at the start of wrapped lines
vim.opt.textwidth = 100  -- Wrap at 100 characters
vim.opt.colorcolumn = "100"  -- Show a vertical line at the wrap point
vim.opt.formatoptions = vim.opt.formatoptions + "j"  -- Remove comment leader when joining lines

-- backups and swaps
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undofile = true

-- highlights
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.ignorecase = true

-- colors
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"

vim.opt.cursorline = true
