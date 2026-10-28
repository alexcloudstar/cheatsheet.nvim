local config = require("cheatsheet.config")

describe("config", function()
    before_each(function()
        config.setup({})
    end)

    it("has defaults before the user passes anything", function()
        assert.are.equal("<leader>cc", config.options.open_key)
        assert.are.same({}, config.options.aliases)
        assert.are.same({}, config.options.categories)
        assert.is_true(config.options.detect_unlisted)
        assert.are.equal("+", config.options.copy_register)
    end)

    it("lets user options override defaults", function()
        config.setup({ open_key = "<leader>?", copy_register = "*" })

        assert.are.equal("<leader>?", config.options.open_key)
        assert.are.equal("*", config.options.copy_register)
    end)

    it("keeps defaults the user did not touch", function()
        config.setup({ open_key = false })

        assert.is_false(config.options.open_key)
        assert.are.equal("<C-b>", config.options.back_key)
        assert.are.equal("<C-a>", config.options.all_key)
    end)

    it("resets to defaults when setup runs again without options", function()
        config.setup({ aliases = { "Cc" } })
        config.setup({})

        assert.are.same({}, config.options.aliases)
    end)
end)
