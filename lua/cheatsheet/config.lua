local M = {}

local DEFAULTS = {
    open_key = "<leader>cc",
    aliases = {},
    categories = {},
    detect_unlisted = true,
    config_dir = nil,
    copy_register = "+",
    back_key = "<C-b>",
    all_key = "<C-a>",
}

M.options = vim.deepcopy(DEFAULTS)

M.setup = function(userOptions)
    M.options = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULTS), userOptions or {})
end

return M
