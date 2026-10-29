local overlay = require("cheatsheet.overlay")

local M = {}

local HIGHLIGHT = "Title"
local CARET_WIDTH = 2
local ASCENDING = "ascending"

M.labels = { "★", "Mode", "Key", "Category", "Description" }

local countVisibleRows = function(picker, resultsWin)
    local resultCount = picker.manager and picker.manager:num_results() or 0
    return math.min(resultCount, vim.api.nvim_win_get_height(resultsWin))
end

local findFirstRow = function(picker, resultsWin)
    local contentTop = vim.api.nvim_win_get_position(resultsWin)[1]
    if picker.sorting_strategy == ASCENDING then
        return contentTop
    end
    return contentTop + vim.api.nvim_win_get_height(resultsWin) - countVisibleRows(picker, resultsWin)
end

local placeAboveFirstRow = function(promptBufnr)
    local picker = overlay.getPicker(promptBufnr)
    local bounds = overlay.getOuterBounds(picker.results_win)
    return {
        row = math.max(findFirstRow(picker, picker.results_win) - 1, bounds.top),
        col = bounds.left + 1,
        width = bounds.width - 2,
    }
end

M.show = function(promptBufnr, displayer)
    local text = displayer(M.labels)
    local reposition = overlay.open(promptBufnr, {
        text = string.rep(" ", CARET_WIDTH) .. text,
        highlight = HIGHLIGHT,
        place = placeAboveFirstRow,
    })
    overlay.getPicker(promptBufnr):register_completion_callback(reposition)
end

return M
