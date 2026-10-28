local config = require("cheatsheet.config")
local pinned = require("cheatsheet.pinned")
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

local createKeyDisplayer = function()
    local items = {
        { width = MARKER_WIDTH },
        { width = MODE_WIDTH },
        { width = KEY_WIDTH },
        { width = CATEGORY_WIDTH },
        { remaining = true },
    }
    return require("telescope.pickers.entry_display").create({ separator = COLUMN_SEPARATOR, items = items })
end

local mapNavigation = function(map, promptBufnr, sourceBuffer, canGoBack)
    local options = config.options
    pinned.show(promptBufnr)
    map({ "i", "n" }, options.all_key, function()
        local query = require("telescope.actions.state").get_current_line()
        closeThen(promptBufnr, function()
            openKeys(rows.ALL_CATEGORY, sourceBuffer, query)
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

-- Hides entries outside the current level while the prompt is empty, and lets
-- everything through once the user types, so search always covers every key.
local scopedSorter = function(baseSorter, isInScope)
    local baseScore = baseSorter.scoring_function
    baseSorter.scoring_function = function(self, prompt, line, entry)
        if not isInScope(entry, prompt) then
            return -1
        end
        return baseScore(self, prompt, line, entry)
    end
    return baseSorter
end

local makeKeyEntry = function(row, displayer)
    return {
        value = row,
        isKey = true,
        ordinal = table.concat({ row.key, row.desc, row.tags, row.categoryLabel, row.modes }, " "),
        display = function()
            return displayer({ row.isCustom and CUSTOM_MARKER or "", row.modes, row.key, row.categoryLabel, row.desc })
        end,
    }
end

local copySelection = function(promptBufnr)
    local selection = require("telescope.actions.state").get_selected_entry()
    if not selection then
        return false
    end
    require("telescope.actions").close(promptBufnr)
    copyKey(selection.value.key)
    return true
end

openCategories = function(sourceBuffer, query)
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local actions = require("telescope.actions")
    local actionState = require("telescope.actions.state")
    local telescopeConfig = require("telescope.config").values

    local allRows, categories = rows.collectAll(sourceBuffer)
    local categoryDisplayer = require("telescope.pickers.entry_display").create({
        separator = COLUMN_SEPARATOR,
        items = {
            { width = CATEGORY_LABEL_WIDTH },
            { width = COUNT_WIDTH },
            { remaining = true },
        },
    })
    local keyDisplayer = createKeyDisplayer()

    local results = {}
    for _, category in ipairs(rows.listCategories(allRows, categories)) do
        table.insert(results, {
            value = category,
            isKey = false,
            ordinal = table.concat({ category.label, category.desc, category.tags or "" }, " "),
            display = function()
                return categoryDisplayer({ category.label, category.count .. " keys", category.desc })
            end,
        })
    end
    for _, row in ipairs(allRows) do
        table.insert(results, makeKeyEntry(row, keyDisplayer))
    end

    pickers.new({}, {
        prompt_title = CATEGORY_TITLE,
        default_text = query,
        finder = finders.new_table({
            results = results,
            entry_maker = function(entry)
                return entry
            end,
        }),
        sorter = scopedSorter(telescopeConfig.generic_sorter({}), function(entry, prompt)
            return (prompt ~= "") == entry.isKey
        end),
        attach_mappings = function(promptBufnr, map)
            actions.select_default:replace(function()
                local selection = actionState.get_selected_entry()
                if not selection then
                    return
                end
                if selection.isKey then
                    copySelection(promptBufnr)
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

openKeys = function(category, sourceBuffer, query)
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local actions = require("telescope.actions")
    local telescopeConfig = require("telescope.config").values
    local options = config.options

    local allRows = rows.collectAll(sourceBuffer)
    local displayer = createKeyDisplayer()

    pickers.new({}, {
        prompt_title = string.format("%s  (%s back, %s all)", category.label, options.back_key, options.all_key),
        default_text = query,
        finder = finders.new_table({
            results = allRows,
            entry_maker = function(row)
                return makeKeyEntry(row, displayer)
            end,
        }),
        sorter = scopedSorter(telescopeConfig.generic_sorter({}), function(entry, prompt)
            return rows.isInScope(entry.value, category.id, prompt)
        end),
        attach_mappings = function(promptBufnr, map)
            actions.select_default:replace(function()
                copySelection(promptBufnr)
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
