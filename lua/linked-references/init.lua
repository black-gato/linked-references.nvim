local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local config = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local M = {}

--local files = vim.fs.find(function(name)
--	return name:match(".*%.md$")
--end, { limit = math.huge, type = "file", path = M.config.path })

local function map(mode, combo, mapping, desc)
	if combo then
		vim.keymap.set(mode, combo, mapping, { silent = true, desc = desc })
	end
end

M.get_alias = function()
	local cmd = "find "
		.. M.config.path
		.. ' -type f -name "*.md" | xargs -I {} yq --front-matter=extract  ".aliases[]" {}'
	local output = vim.fn.system(cmd)
	local alias_list = vim.split(output, "\n")
	return alias_list
end

M.setup = function(opts)
	local default = {
		path = ".",
		mappings = {
			search_alias = "<leader>;",
		},
	}
	M.config = vim.tbl_extend("keep", opts or {}, default)
	map("n", M.config.mappings.search_alias, M.pick_alias, "Search alias")
end
---@param input string
local create_tmp_buf = function(input)
	local cmd = vim.fn.system("rg " .. M.config.path .. ' -e ".* \\[\\[.*\\|' .. input .. '\\]\\].*"')
	local lines = vim.split(cmd, "\n")
	local header = ""
	local output = {}
	for _, v in pairs(lines) do
		local file, sentince = string.match(v, "(.+):(.+) %[%[") -- we are grabbing the file and the string tagged
		local _, _, match = string.match(header, "### %[(.+)%]") -- we are grapping the filename form the markdown link
		if file ~= nil then
			if (match ~= file) or (header ~= "") then
				header = string.format('### [%s]("%s")', file, file)
				table.insert(output, header)
			end

			sentince = string.format('  - "%s"', sentince)
			table.insert(output, sentince)
		end
	end
	vim.cmd("vsplit | enew | setfiletype markdown | set fileencoding=utf-8")
	local bufnr = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, output)
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
					create_tmp_buf(selection.value)
				end)
				return true
			end,
		})
		:find()
end

return M
