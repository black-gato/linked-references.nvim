local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local config = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
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
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					print(vim.inspect(selection.value))
				end)
				return true
			end,
		})
		:find()
end
M.pick_alias()

return M
