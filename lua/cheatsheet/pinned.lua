local config = require("cheatsheet.config")
local overlay = require("cheatsheet.overlay")

local M = {}

local SEPARATOR = "   "
local HIGHLIGHT = "Title"

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

local placeBelowPicker = function(text)
    return function(promptBufnr)
        local picker = overlay.getPicker(promptBufnr)
        local results = overlay.getOuterBounds(picker.results_win)
        local prompt = overlay.getOuterBounds(picker.prompt_win)
        local width = math.min(vim.fn.strdisplaywidth(text), vim.o.columns)
        local centered = results.left + math.floor((results.width - width) / 2)
        return {
            row = math.min(math.max(results.bottom, prompt.bottom), vim.o.lines - 1),
            col = math.max(centered, 0),
            width = width,
        }
    end
end

M.show = function(promptBufnr)
    if not config.options.pinned then
        return
    end
    local text = M.text()
    overlay.open(promptBufnr, { text = text, highlight = HIGHLIGHT, place = placeBelowPicker(text) })
end

return M
