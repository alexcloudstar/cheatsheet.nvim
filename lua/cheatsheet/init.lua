local config = require("cheatsheet.config")

local M = {}

local COMMAND_DESC = "Open the keybinding cheatsheet"
local MISSING_TELESCOPE_MESSAGE = "cheatsheet.nvim requires telescope.nvim"

M.open = function()
    if not pcall(require, "telescope") then
        vim.notify(MISSING_TELESCOPE_MESSAGE, vim.log.levels.ERROR)
        return
    end
    require("cheatsheet.picker").open(vim.api.nvim_get_current_buf())
end

M.setup = function(userOptions)
    config.setup(userOptions)
    local options = config.options

    for _, alias in ipairs(options.aliases) do
        vim.api.nvim_create_user_command(alias, function() M.open() end, { desc = COMMAND_DESC })
    end

    if options.open_key then
        vim.keymap.set("n", options.open_key, M.open, { desc = COMMAND_DESC })
    end
end

return M
