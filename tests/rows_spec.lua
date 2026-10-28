local config = require("cheatsheet.config")
local rows = require("cheatsheet.rows")

local normalizeKeyForTest = function(key)
    local normalized = key:lower():gsub("<leader>", " "):gsub("<space>", " ")
    return normalized
end

local findRows = function(allRows, predicate)
    return vim.tbl_filter(predicate, allRows)
end

local findCategory = function(categories, id)
    for _, category in ipairs(categories) do
        if category.id == id then
            return category
        end
    end
end

local indexOfCategory = function(categories, id)
    for index, category in ipairs(categories) do
        if category.id == id then
            return index
        end
    end
end

describe("rows", function()
    before_each(function()
        config.setup({ open_key = false, detect_unlisted = false })
    end)

    describe("built-in data", function()
        it("includes the expected categories", function()
            local _, categories = rows.collectAll()

            assert.is_not_nil(findCategory(categories, "move"))
            assert.is_not_nil(findCategory(categories, "edit"))
            assert.is_not_nil(findCategory(categories, "notation"))
        end)

        it("marks no built-in row as custom", function()
            local allRows = rows.collectAll()

            assert.are.equal(0, #findRows(allRows, function(row)
                return row.isCustom
            end))
        end)

        it("leaves the mode column empty for built-in rows", function()
            local allRows = rows.collectAll()
            local row = findRows(allRows, function(candidate)
                return candidate.key == "h j k l"
            end)[1]

            assert.are.equal("", row.modes)
        end)
    end)

    describe("user categories", function()
        it("adds entries to an existing category and marks them custom", function()
            config.setup({
                open_key = false,
                detect_unlisted = false,
                categories = { { id = "files", entries = { { key = "<leader>pf", desc = "Find files" } } } },
            })

            local allRows = rows.collectAll()
            local row = findRows(allRows, function(candidate)
                return candidate.key == "<leader>pf"
            end)[1]

            assert.are.equal("files", row.categoryId)
            assert.is_true(row.isCustom)
            assert.are.equal("n", row.modes)
        end)

        it("respects custom = false", function()
            config.setup({
                open_key = false,
                detect_unlisted = false,
                categories = { { id = "files", entries = { { key = "gx", desc = "Open link", custom = false } } } },
            })

            local row = findRows(rows.collectAll(), function(candidate)
                return candidate.key == "gx"
            end)[1]

            assert.is_false(row.isCustom)
        end)

        it("replaces a built-in entry with the same key and mode", function()
            config.setup({
                open_key = false,
                detect_unlisted = false,
                categories = { { id = "search", entries = { { key = "n", desc = "Next match, centered" } } } },
            })

            local matches = findRows(rows.collectAll(), function(row)
                return row.categoryId == "search" and row.key == "n"
            end)

            assert.are.equal(1, #matches)
            assert.are.equal("Next match, centered", matches[1].desc)
            assert.is_true(matches[1].isCustom)
        end)

        it("keeps a built-in entry when the user key differs in mode", function()
            config.setup({
                open_key = false,
                detect_unlisted = false,
                categories = { { id = "edit", entries = { { key = "J", modes = "v", desc = "Move selection down" } } } },
            })

            local matches = findRows(rows.collectAll(), function(row)
                return row.categoryId == "edit" and row.key == "J"
            end)

            assert.are.equal(2, #matches)
        end)

        it("matches <leader> and the leader key as the same key", function()
            config.setup({
                open_key = false,
                detect_unlisted = false,
                categories = {
                    {
                        id = "edit",
                        entries = {
                            { key = "<leader>y", desc = "first" },
                            { key = "<space>y", desc = "second" },
                        },
                    },
                    { id = "edit", entries = { { key = "<leader>y", desc = "third" } } },
                },
            })

            local leaderRows = findRows(rows.collectAll(), function(row)
                return row.categoryId == "edit" and row.isCustom and normalizeKeyForTest(row.key) == " y"
            end)

            assert.are.equal(1, #leaderRows)
            assert.are.equal("third", leaderRows[1].desc)
        end)

        it("creates a new category before the notation category", function()
            config.setup({
                open_key = false,
                detect_unlisted = false,
                categories = {
                    { id = "docker", label = "Docker", desc = "containers", entries = { { key = "<leader>dd", desc = "Up" } } },
                },
            })

            local _, categories = rows.collectAll()

            assert.are.equal("Docker", findCategory(categories, "docker").label)
            assert.are.equal(
                indexOfCategory(categories, "notation") - 1,
                indexOfCategory(categories, "docker")
            )
        end)

        it("does not change the built-in data between calls", function()
            config.setup({
                open_key = false,
                detect_unlisted = false,
                categories = { { id = "files", entries = { { key = "<leader>pf", desc = "Find files" } } } },
            })
            rows.collectAll()
            config.setup({ open_key = false, detect_unlisted = false })

            local matches = findRows(rows.collectAll(), function(row)
                return row.key == "<leader>pf"
            end)

            assert.are.equal(0, #matches)
        end)
    end)

    describe("open_key", function()
        it("adds an entry for the open key to the notation category", function()
            config.setup({ open_key = "<leader>cc", detect_unlisted = false })

            local matches = findRows(rows.collectAll(), function(row)
                return row.categoryId == "notation" and row.key == "<leader>cc"
            end)

            assert.are.equal(1, #matches)
            assert.is_true(matches[1].isCustom)
        end)

        it("adds nothing when open_key is false", function()
            local matches = findRows(rows.collectAll(), function(row)
                return row.key == "<leader>cc"
            end)

            assert.are.equal(0, #matches)
        end)
    end)

    describe("select and listCategories", function()
        local allRows, categories

        before_each(function()
            config.setup({
                open_key = false,
                detect_unlisted = false,
                categories = {
                    {
                        id = "files",
                        entries = {
                            { key = "<leader>pf", desc = "Find files" },
                            { key = "<C-p>", desc = "Git files" },
                        },
                    },
                },
            })
            allRows, categories = rows.collectAll()
        end)

        it("selects only the rows of one category", function()
            local selected = rows.select(allRows, "files")

            for _, row in ipairs(selected) do
                assert.are.equal("files", row.categoryId)
            end
        end)

        it("selects every row for the all view", function()
            assert.are.equal(#allRows, #rows.select(allRows, rows.ALL_ID))
        end)

        it("selects only custom rows for the mine view", function()
            local selected = rows.select(allRows, rows.MINE_ID)

            assert.are.equal(2, #selected)
            for _, row in ipairs(selected) do
                assert.is_true(row.isCustom)
            end
        end)

        it("limits a view to its own rows while the query is empty", function()
            local files = rows.select(allRows, "files")
            local inScope = vim.tbl_filter(function(row)
                return rows.isInScope(row, "files", "")
            end, allRows)

            assert.are.equal(#files, #inScope)
            assert.is_true(#inScope < #allRows)
        end)

        it("searches every row from any view once the user types", function()
            for _, row in ipairs(allRows) do
                assert.is_true(rows.isInScope(row, "files", "delete"))
            end
        end)

        it("treats a nil query like an empty one", function()
            local outside = findRows(allRows, function(row)
                return row.categoryId ~= "files"
            end)[1]

            assert.is_false(rows.isInScope(outside, "files", nil))
        end)

        it("keeps the all view showing everything with an empty query", function()
            for _, row in ipairs(allRows) do
                assert.is_true(rows.isInScope(row, rows.ALL_ID, ""))
            end
        end)

        it("lists every category plus My maps, with counts", function()
            local listed = rows.listCategories(allRows, categories)
            local mine = findCategory(listed, rows.MINE_ID)

            assert.are.equal(#categories + 1, #listed)
            assert.are.equal(2, mine.count)
            assert.are.equal(#rows.select(allRows, "files"), findCategory(listed, "files").count)
        end)

        it("hides the unlisted category when there are no unlisted maps", function()
            local listed = rows.listCategories(allRows, categories)

            assert.is_nil(findCategory(listed, rows.UNLISTED_ID))
        end)
    end)

    describe("unlisted map detection", function()
        local configDir
        local createdKeys

        local defineMapsInConfigDir = function(source)
            local path = configDir .. "/maps.lua"
            vim.fn.writefile(vim.split(source, "\n"), path)
            vim.cmd.source(path)
        end

        before_each(function()
            configDir = vim.fn.tempname()
            vim.fn.mkdir(configDir, "p")
            createdKeys = {}
        end)

        after_each(function()
            for _, key in ipairs(createdKeys) do
                pcall(vim.keymap.del, "n", key)
            end
            vim.fn.delete(configDir, "rf")
        end)

        local remember = function(key)
            table.insert(createdKeys, key)
        end

        it("lists a map from the config dir that is missing from the cheatsheet", function()
            remember("<leader>zz")
            config.setup({ open_key = false, config_dir = configDir })
            defineMapsInConfigDir([[vim.keymap.set("n", "<leader>zz", "<cmd>echo 1<CR>", { desc = "Forgotten" })]])

            local unlisted = rows.select(rows.collectAll(), rows.UNLISTED_ID)

            assert.are.equal(1, #unlisted)
            assert.are.equal("<leader>zz", unlisted[1].key)
            assert.are.equal("Forgotten", unlisted[1].desc)
            assert.are.equal("n", unlisted[1].modes)
        end)

        it("does not list a map that the user already added to the cheatsheet", function()
            remember("<leader>zz")
            config.setup({
                open_key = false,
                config_dir = configDir,
                categories = { { id = "edit", entries = { { key = "<space>zz", desc = "Listed" } } } },
            })
            defineMapsInConfigDir([[vim.keymap.set("n", "<leader>zz", "<cmd>echo 1<CR>")]])

            local unlisted = rows.select(rows.collectAll(), rows.UNLISTED_ID)

            assert.are.equal(0, #unlisted)
        end)

        it("ignores maps defined outside the config dir", function()
            remember("<leader>zq")
            config.setup({ open_key = false, config_dir = configDir .. "/does-not-exist" })
            defineMapsInConfigDir([[vim.keymap.set("n", "<leader>zq", "<cmd>echo 1<CR>")]])

            local unlisted = rows.select(rows.collectAll(), rows.UNLISTED_ID)

            assert.are.equal(0, #unlisted)
        end)

        it("skips detection when detect_unlisted is false", function()
            remember("<leader>zz")
            config.setup({ open_key = false, config_dir = configDir, detect_unlisted = false })
            defineMapsInConfigDir([[vim.keymap.set("n", "<leader>zz", "<cmd>echo 1<CR>")]])

            local unlisted = rows.select(rows.collectAll(), rows.UNLISTED_ID)

            assert.are.equal(0, #unlisted)
        end)

        it("shows the unlisted category in the category list when maps are missing", function()
            remember("<leader>zz")
            config.setup({ open_key = false, config_dir = configDir })
            defineMapsInConfigDir([[vim.keymap.set("n", "<leader>zz", "<cmd>echo 1<CR>")]])

            local allRows, categories = rows.collectAll()
            local listed = rows.listCategories(allRows, categories)

            assert.are.equal(1, findCategory(listed, rows.UNLISTED_ID).count)
        end)
    end)
end)
