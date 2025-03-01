-- Disable nvim-notify
local notify = require("notify")
notify.setup({
  -- Completely disable notifications
  level = "off",
  background_colour = "#000000",
  render = "minimal",
  stages = "static",
  timeout = 1,  -- Very short timeout
  max_width = 1,
  max_height = 1,
})

-- Override the default notify function to do nothing
vim.notify = function(...)
  -- Do nothing
end