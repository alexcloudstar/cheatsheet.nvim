local config = require("cheatsheet.config")
local builtinCategories = require("cheatsheet.data")

local M = {}

M.ALL_ID = "all"
M.MINE_ID = "mine"
M.UNLISTED_ID = "unlisted"

M.ALL_CATEGORY = {
    id = M.ALL_ID,
    label = "All keys",
    desc = "everything in one list",
}

M.MINE_CATEGORY = {
    id = M.MINE_ID,
    label = "My maps",
    desc = "only the keys you configured",
    tags = "custom mine configured personal",
}

M.UNLISTED_CATEGORY = {
    id = M.UNLISTED_ID,
    label = "Unlisted maps",
    desc = "live maps from your config that are not in the cheatsheet",
    tags = "missing new sync",
}

local NOTATION_ID = "notation"
local DEFAULT_MODES = "n"
local LIVE_MODES = { "n", "v", "i" }
local FUNCTION_DESC = "(lua function)"
local OWN_ENTRY_DESC = "Open this cheatsheet"
local OWN_ENTRY_TAGS = "keys help"

local normalizeKey = function(key)
    local leader = vim.g.mapleader or "\\"
    local normalized = key:lower():gsub("<leader>", leader):gsub("<space>", " ")
    return normalized
end

local toIdentity = function(mode, key)
    local normalizedMode = mode == "x" and "v" or mode
    return normalizedMode .. "|" .. normalizeKey(key)
end

local toEntryIdentity = function(entry)
    return toIdentity(entry.modes or DEFAULT_MODES, entry.key)
end

local normalizeUserEntry = function(entry)
    return vim.tbl_extend("keep", entry, { custom = true })
end

local findCategoryIndex = function(categories, id)
    for index, category in ipairs(categories) do
        if category.id == id then
            return index
        end
    end
end

local findInsertionIndex = function(categories)
    return findCategoryIndex(categories, NOTATION_ID) or (#categories + 1)
end

local mergeUserCategory = function(categories, userCategory)
    local userEntries = vim.tbl_map(normalizeUserEntry, userCategory.entries or {})
    local index = findCategoryIndex(categories, userCategory.id)

    if not index then
        table.insert(categories, findInsertionIndex(categories), {
            id = userCategory.id,
            label = userCategory.label or userCategory.id,
            desc = userCategory.desc or "",
            tags = userCategory.tags or "",
            entries = userEntries,
        })
        return
    end

    local category = categories[index]
    local overridden = {}
    for _, entry in ipairs(userEntries) do
        overridden[toEntryIdentity(entry)] = true
    end
    category.entries = vim.tbl_filter(function(entry)
        return not overridden[toEntryIdentity(entry)]
    end, category.entries)
    vim.list_extend(category.entries, userEntries)
    category.label = userCategory.label or category.label
    category.desc = userCategory.desc or category.desc
    category.tags = userCategory.tags and (category.tags .. " " .. userCategory.tags) or category.tags
end

local buildOwnCategory = function(openKey)
    return {
        id = NOTATION_ID,
        entries = { { key = openKey, desc = OWN_ENTRY_DESC, tags = OWN_ENTRY_TAGS } },
    }
end

local buildCategories = function()
    local options = config.options
    local categories = vim.deepcopy(builtinCategories)
    if options.open_key then
        mergeUserCategory(categories, buildOwnCategory(options.open_key))
    end
    for _, userCategory in ipairs(options.categories) do
        mergeUserCategory(categories, userCategory)
    end
    return categories
end

local collectDataRows = function(categories)
    local rows = {}
    for _, category in ipairs(categories) do
        for _, entry in ipairs(category.entries) do
            local isCustom = entry.custom == true
            table.insert(rows, {
                categoryId = category.id,
                categoryLabel = category.label,
                isCustom = isCustom,
                modes = entry.modes or (isCustom and DEFAULT_MODES or ""),
                key = entry.key,
                desc = entry.desc,
                tags = entry.tags or "",
            })
        end
    end
    return rows
end

local buildListedIdentities = function(dataRows)
    local identities = {}
    for _, row in ipairs(dataRows) do
        if row.isCustom then
            for mode in row.modes:gmatch(".") do
                identities[toIdentity(mode, row.key)] = true
            end
        end
    end
    return identities
end

local isUserConfigMapping = function(mapping)
    if mapping.sid <= 0 then
        return false
    end
    local scripts = vim.fn.getscriptinfo({ sid = mapping.sid })
    if #scripts == 0 then
        return false
    end
    local configDir = vim.fn.resolve(config.options.config_dir or vim.fn.stdpath("config"))
    return vim.startswith(vim.fn.resolve(scripts[1].name), configDir)
end

local describeMapping = function(mapping)
    if mapping.desc then
        return mapping.desc
    end
    if mapping.rhs and mapping.rhs ~= "" then
        return mapping.rhs
    end
    return FUNCTION_DESC
end

local collectUnlistedRows = function(listedIdentities, sourceBuffer)
    local rows = {}
    local seen = {}
    for _, mode in ipairs(LIVE_MODES) do
        local mappings = vim.api.nvim_get_keymap(mode)
        if sourceBuffer and vim.api.nvim_buf_is_valid(sourceBuffer) then
            vim.list_extend(mappings, vim.api.nvim_buf_get_keymap(sourceBuffer, mode))
        end
        for _, mapping in ipairs(mappings) do
            local identity = toIdentity(mode, mapping.lhs)
            if isUserConfigMapping(mapping) and not listedIdentities[identity] and not seen[identity] then
                seen[identity] = true
                table.insert(rows, {
                    categoryId = M.UNLISTED_ID,
                    categoryLabel = M.UNLISTED_CATEGORY.label,
                    isCustom = true,
                    modes = mode,
                    key = mapping.lhs:gsub("^ ", "<leader>"),
                    desc = describeMapping(mapping),
                    tags = "",
                })
            end
        end
    end
    table.sort(rows, function(a, b)
        return a.key < b.key
    end)
    return rows
end

M.collectAll = function(sourceBuffer)
    local categories = buildCategories()
    local rows = collectDataRows(categories)
    if config.options.detect_unlisted then
        vim.list_extend(rows, collectUnlistedRows(buildListedIdentities(rows), sourceBuffer))
    end
    return rows, categories
end

M.select = function(allRows, viewId)
    if viewId == M.ALL_ID then
        return allRows
    end
    if viewId == M.MINE_ID then
        return vim.tbl_filter(function(row)
            return row.isCustom and row.categoryId ~= M.UNLISTED_ID
        end, allRows)
    end
    return vim.tbl_filter(function(row)
        return row.categoryId == viewId
    end, allRows)
end

M.listCategories = function(allRows, categories)
    local listed = vim.list_slice(categories)
    table.insert(listed, M.MINE_CATEGORY)
    if #M.select(allRows, M.UNLISTED_ID) > 0 then
        table.insert(listed, M.UNLISTED_CATEGORY)
    end
    return vim.tbl_map(function(category)
        return vim.tbl_extend("force", category, { count = #M.select(allRows, category.id) })
    end, listed)
end

return M
