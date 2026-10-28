local config = require("cheatsheet.config")
local pinned = require("cheatsheet.pinned")

describe("pinned", function()
    before_each(function()
        config.setup({})
    end)

    it("explains leader and the modifier keys", function()
        local text = pinned.text()

        assert.is_truthy(text:find("<leader>", 1, true))
        assert.is_truthy(text:find("<C-x> = Ctrl+x", 1, true))
        assert.is_truthy(text:find("<S-x> = Shift+x", 1, true))
        assert.is_truthy(text:find("<A-x> = Alt+x", 1, true))
    end)

    it("shows the real leader key", function()
        local previous = vim.g.mapleader
        vim.g.mapleader = " "
        assert.is_truthy(pinned.text():find("<leader> = Space", 1, true))
        vim.g.mapleader = ","
        assert.is_truthy(pinned.text():find("<leader> = ,", 1, true))
        vim.g.mapleader = previous
    end)

    it("is on by default and can be turned off", function()
        assert.is_true(config.options.pinned)
        config.setup({ pinned = false })
        assert.is_false(config.options.pinned)
    end)
end)
