require("bufferline").setup({
    options = {
        mode = "tabs",
        separator_style = "slant",
        show_buffer_close_buttons = false,
        show_close_icon = false,
        diagnostics = "nvim_lsp",
        diagnostics_indicator = function(count, level)
            local icon = level:match("error") and " " or " "
            return icon .. count
        end,
        always_show_bufferline = true,
        offsets = {
            {
                filetype = "NvimTree",
                text = "Explorer",
                highlight = "Directory",
                separator = true,
            },
        },
    },
})
