local PLUGIN_DIR = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local DEFAULT_PLENARY_DIR = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"

local plenaryDir = vim.env.PLENARY_DIR or DEFAULT_PLENARY_DIR

vim.opt.runtimepath:prepend(plenaryDir)
vim.opt.runtimepath:prepend(PLUGIN_DIR)
vim.opt.swapfile = false
vim.g.mapleader = " "

vim.cmd("runtime plugin/plenary.vim")
