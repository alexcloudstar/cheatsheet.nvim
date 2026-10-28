local config = require("cheatsheet.config")

local M = {}

local SEPARATOR = "   "
local ZINDEX = 10

local describeLeader = function()
    local leader = vim.g.mapleader or "\\"
    return leader == " " and "Space" or leader
end

M.lines = function()
    return {
        "<leader> = " .. describeLeader(),
        "<C-x> = Ctrl+x",
        "<S-x> = Shift+x",
        "<A-x> = Alt+x",
        "<CR> = Enter",
    }
end

M.text = function()
    return " " .. table.concat(M.lines(), SEPARATOR) .. " "
end

M.show = function(promptBufnr)
    if not config.options.pinned then
        return
    end
    local text = M.text()
    local width = math.min(vim.fn.strdisplaywidth(text), vim.o.columns)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { text })
    local winnr = vim.api.nvim_open_win(bufnr, false, {
        relative = "editor",
        row = 0,
        col = math.floor((vim.o.columns - width) / 2),
        width = width,
        height = 1,
        style = "minimal",
        border = "none",
        focusable = false,
        zindex = ZINDEX,
    })
    vim.wo[winnr].winhighlight = "Normal:Title"
    vim.api.nvim_create_autocmd("BufWipeout", {
        buffer = promptBufnr,
        once = true,
        callback = function()
            if vim.api.nvim_win_is_valid(winnr) then
                vim.api.nvim_win_close(winnr, true)
            end
        end,
    })
end

return M
