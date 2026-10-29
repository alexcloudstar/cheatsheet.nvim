local M = {}

local ZINDEX = 200
local BORDER_SIZE = 1

M.getPicker = function(promptBufnr)
    return require("telescope.actions.state").get_current_picker(promptBufnr)
end

M.getOuterBounds = function(winnr)
    local row, col = unpack(vim.api.nvim_win_get_position(winnr))
    return {
        top = row - BORDER_SIZE,
        bottom = row + vim.api.nvim_win_get_height(winnr) + BORDER_SIZE,
        left = col - BORDER_SIZE,
        width = vim.api.nvim_win_get_width(winnr) + 2 * BORDER_SIZE,
    }
end

M.open = function(promptBufnr, options)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { options.text })
    local winnr

    local place = function()
        if not vim.api.nvim_buf_is_valid(promptBufnr) then
            return
        end
        local placement = options.place(promptBufnr)
        local windowConfig = {
            relative = "editor",
            row = placement.row,
            col = placement.col,
            width = placement.width,
            height = 1,
        }
        if winnr and vim.api.nvim_win_is_valid(winnr) then
            vim.api.nvim_win_set_config(winnr, windowConfig)
            return
        end
        winnr = vim.api.nvim_open_win(
            bufnr,
            false,
            vim.tbl_extend("error", windowConfig, {
                style = "minimal",
                border = "none",
                focusable = false,
                zindex = ZINDEX,
            })
        )
        vim.wo[winnr].winhighlight = "Normal:" .. options.highlight
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

    vim.schedule(place)
    return place
end

return M
