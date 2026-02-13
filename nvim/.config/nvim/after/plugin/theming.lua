-- Noctalia/matugen auto-theming via base16-nvim
-- Colors are generated from wallpaper -> Material Design 3 tokens -> base16 palette

local function apply_colors()
    local ok, colors = pcall(require, "noctalia_colors")
    if not ok then return end
    package.loaded["noctalia_colors"] = nil

    require("base16-colorscheme").setup(colors)

    vim.api.nvim_set_hl(0, "Comment", { italic = true, fg = colors.base03 })
    vim.api.nvim_set_hl(0, "Conditional", { italic = true })
end

apply_colors()

vim.api.nvim_create_autocmd("Signal", {
    pattern = "SIGUSR1",
    callback = function() apply_colors() end,
})
