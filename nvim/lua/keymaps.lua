-- Basic shortcuts
vim.g.mapleader = ","
vim.keymap.set("n", ";", ":")
vim.keymap.set("i", "jj", "<Esc>")

-- Special stuff
-- Shifting stuff in visual mode
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Pasting from the void
vim.keymap.set("x", "<leader>p", [["_dP]])

vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true })

-- Windowpanes
vim.o.splitbelow		= true
vim.o.splitright		= true
vim.keymap.set("n", "<leader>w", "<C-w>",  {noremap = true, silent = true})
vim.keymap.set("n", "<C-h>", "<C-w>h",  {noremap = true, silent = true})
vim.keymap.set("n", "<C-j>", "<C-w>j",  {noremap = true, silent = true})
vim.keymap.set("n", "<C-k>", "<C-w>k",  {noremap = true, silent = true})
vim.keymap.set("n", "<C-l>", "<C-w>l",  {noremap = true, silent = true})

-- Tabs
vim.keymap.set("n", "<leader>tn", ":tab split<CR>",  {noremap = true, silent = true})
vim.keymap.set("n", "<C-S-tab>", ":tabp<CR>",  {noremap = true, silent = true})
vim.keymap.set("n", "<C-tab>", ":tabn<CR>",  {noremap = true, silent = true})
vim.keymap.set("n", "<C-S-PageUp>", ":tabmove -1<CR>",  {noremap = true, silent = true})
vim.keymap.set("n", "<C-S-PageDown>", ":tabmove +1<CR>",  {noremap = true, silent = true})
vim.keymap.set("n", "<S-J>", ":tabp<CR>",  {noremap = true, silent = true})
vim.keymap.set("n", "<S-K>", ":tabn<CR>",  {noremap = true, silent = true})

-- Tmux-Sessionizer
vim.keymap.set("n", "<C-f>", "<cmd>silent !tmux display-popup tms switch<CR>")
vim.keymap.set("n", "<C-n>", "<cmd>silent !tmux display-popup tms<CR>")

-- Clipboard
vim.opt.clipboard = 'unnamedplus'

-- Zen mode
vim.keymap.set("n", "<leader>z", ":ZenMode<CR>",  {noremap = true, silent = true})

-- tree
vim.keymap.set("n", "<leader>nt", ":NvimTreeToggle<CR>")

-- fterm
vim.keymap.set('n', '<A-i>', ':lua require("FTerm").toggle()<CR>')
vim.keymap.set('t', '<A-i>', '<C-\\><C-n><CMD>lua require("FTerm").toggle()<CR>')

-- lazygit
vim.keymap.set('n', '<leader>lg', ':LazyGit<CR>')

-- noice dismiss
vim.keymap.set('n', '<leader>nd', ':Noice dismiss<CR>')

-- emmett
vim.g.user_emmet_leader_key = "<C-e>"
