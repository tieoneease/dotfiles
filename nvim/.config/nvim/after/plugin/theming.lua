-- Noctalia/matugen auto-theming via base16-nvim
-- Colors are generated from wallpaper -> Material Design 3 tokens -> base16 palette

require("base16-colorscheme").with_config({
    telescope = false,
    telescope_borders = false,
})

local colors_file = vim.fn.stdpath("config") .. "/lua/noctalia_colors.lua"

local function apply_colors()
    if vim.fn.filereadable(colors_file) == 0 then return end
    dofile(colors_file)
end

apply_colors()

vim.api.nvim_create_autocmd("Signal", {
    pattern = "SIGUSR1",
    callback = function() apply_colors() end,
})
