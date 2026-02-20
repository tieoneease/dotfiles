require('telescope').setup({
    defaults = {
        layout_strategy = "horizontal",
        layout_config = {
            horizontal = {
                prompt_position = "top",
                preview_width = 0.55,
            },
            width = 0.85,
            height = 0.80,
        },
        sorting_strategy = "ascending",
        borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
        prompt_prefix = "   ",
        selection_caret = "  ",
        entry_prefix = "  ",
    },
})

local builtin = require('telescope.builtin')
vim.keymap.set('n', '<C-p>', function()
    local ok = pcall(builtin.git_files, {})
    if not ok then
        builtin.find_files({})
    end
end, {})
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fa', builtin.live_grep, {})
vim.keymap.set('n', '<leader>fw', builtin.grep_string, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})
vim.keymap.set('n', '<leader>fk', builtin.commands, {})
