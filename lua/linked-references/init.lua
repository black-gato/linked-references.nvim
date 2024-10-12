local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local config = require("telescope.config").values
local log = require("plenary.log"):new()
log.level = "debug"

local M = {}

M.get_alias = function()
	local cmd =
		'find /Users/anthonymirville/Projects/Life -type f -name "*.md" | xargs -I {} yq --front-matter=extract  ".aliases[]" {}'
	local output = vim.fn.system(cmd)
	local a = vim.split(output, "\n")

	return a
end

M.pick_alias = function(opts)
	pickers
		.new(opts, {
			finder = finders.new_table({
				unpack(M.get_alias()),
			}),
			sorter = config.generic_sorter(opts),
		})
		:find()
end
M.pick_alias()

return M
