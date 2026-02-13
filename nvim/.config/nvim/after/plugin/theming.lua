-- Noctalia/matugen auto-theming via base16-nvim
-- Colors are generated from wallpaper -> Material Design 3 tokens -> base16 palette

local function apply_colors()
    local ok, colors = pcall(require, "noctalia_colors")
    if not ok then
        -- Fallback: use a built-in base16 theme if generated colors aren't available yet
        vim.cmd.colorscheme("base16-default-dark")
        return
    end

    -- Clear cached module so re-require picks up file changes
    package.loaded["noctalia_colors"] = nil

    require("base16-colorscheme").setup(colors)

    -- Transparent background
    vim.api.nvim_set_hl(0, "Normal", { bg = "NONE" })
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "NONE" })

    -- Style preferences
    vim.api.nvim_set_hl(0, "Comment", { italic = true, fg = colors.base03 })
    vim.api.nvim_set_hl(0, "Conditional", { italic = true })
end

-- Apply on startup
apply_colors()

-- Live-reload on SIGUSR1 (sent by matugen post_hook)
vim.api.nvim_create_autocmd("Signal", {
    pattern = "SIGUSR1",
    callback = function()
        apply_colors()
    end,
})
