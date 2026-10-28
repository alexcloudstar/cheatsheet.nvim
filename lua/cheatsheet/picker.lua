local config = require("cheatsheet.config")
local rows = require("cheatsheet.rows")

local M = {}

local CATEGORY_TITLE = "Cheatsheet: what do you want to do?"
local CATEGORY_LABEL_WIDTH = 26
local COUNT_WIDTH = 8
local CUSTOM_MARKER = "★"
local MARKER_WIDTH = 1
local CATEGORY_WIDTH = 24
local MODE_WIDTH = 3
local KEY_WIDTH = 26
local COLUMN_SEPARATOR = " │ "

local openCategories
local openKeys

local copyKey = function(key)
    vim.fn.setreg(config.options.copy_register, key)
    vim.notify("Copied " .. key)
end

local closeThen = function(promptBufnr, nextStep)
    require("telescope.actions").close(promptBufnr)
    vim.schedule(nextStep)
end

local createKeyDisplayer = function(showCategory)
    local items = {
        { width = MARKER_WIDTH },
        { width = MODE_WIDTH },
        { width = KEY_WIDTH },
    }
    if showCategory then
        table.insert(items, { width = CATEGORY_WIDTH })
    end
    table.insert(items, { remaining = true })
    return require("telescope.pickers.entry_display").create({ separator = COLUMN_SEPARATOR, items = items })
end

local mapNavigation = function(map, promptBufnr, sourceBuffer, canGoBack)
    local options = config.options
    map({ "i", "n" }, options.all_key, function()
        closeThen(promptBufnr, function()
            openKeys(rows.ALL_CATEGORY, sourceBuffer)
        end)
    end)
    if canGoBack then
        map({ "i", "n" }, options.back_key, function()
            closeThen(promptBufnr, function()
                openCategories(sourceBuffer)
            end)
        end)
    end
end

openCategories = function(sourceBuffer)
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local actions = require("telescope.actions")
    local actionState = require("telescope.actions.state")
    local telescopeConfig = require("telescope.config").values

    local allRows, categories = rows.collectAll(sourceBuffer)
    local displayer = require("telescope.pickers.entry_display").create({
        separator = COLUMN_SEPARATOR,
        items = {
            { width = CATEGORY_LABEL_WIDTH },
            { width = COUNT_WIDTH },
            { remaining = true },
        },
    })

    pickers.new({}, {
        prompt_title = CATEGORY_TITLE,
        finder = finders.new_table({
            results = rows.listCategories(allRows, categories),
            entry_maker = function(category)
                return {
                    value = category,
                    ordinal = table.concat({ category.label, category.desc, category.tags or "" }, " "),
                    display = function()
                        return displayer({ category.label, category.count .. " keys", category.desc })
                    end,
                }
            end,
        }),
        sorter = telescopeConfig.generic_sorter({}),
        attach_mappings = function(promptBufnr, map)
            actions.select_default:replace(function()
                local selection = actionState.get_selected_entry()
                if not selection then
                    return
                end
                closeThen(promptBufnr, function()
                    openKeys(selection.value, sourceBuffer)
                end)
            end)
            mapNavigation(map, promptBufnr, sourceBuffer, false)
            return true
        end,
    }):find()
end

openKeys = function(category, sourceBuffer)
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local actions = require("telescope.actions")
    local actionState = require("telescope.actions.state")
    local telescopeConfig = require("telescope.config").values
    local options = config.options

    local keyRows = rows.select((rows.collectAll(sourceBuffer)), category.id)
    local showCategory = category.id == rows.ALL_ID or category.id == rows.MINE_ID
    local displayer = createKeyDisplayer(showCategory)

    pickers.new({}, {
        prompt_title = string.format("%s  (%s back, %s all)", category.label, options.back_key, options.all_key),
        finder = finders.new_table({
            results = keyRows,
            entry_maker = function(row)
                return {
                    value = row,
                    ordinal = table.concat({ row.key, row.desc, row.tags, row.categoryLabel, row.modes }, " "),
                    display = function()
                        local columns = { row.isCustom and CUSTOM_MARKER or "", row.modes, row.key }
                        if showCategory then
                            table.insert(columns, row.categoryLabel)
                        end
                        table.insert(columns, row.desc)
                        return displayer(columns)
                    end,
                }
            end,
        }),
        sorter = telescopeConfig.generic_sorter({}),
        attach_mappings = function(promptBufnr, map)
            actions.select_default:replace(function()
                local selection = actionState.get_selected_entry()
                if not selection then
                    return
                end
                actions.close(promptBufnr)
                copyKey(selection.value.key)
            end)
            mapNavigation(map, promptBufnr, sourceBuffer, true)
            return true
        end,
    }):find()
end

M.open = function(sourceBuffer)
    openCategories(sourceBuffer)
end

return M
