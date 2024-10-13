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

M.create_tmp_buf = function(input)
	local cmd = vim.fn.system('rg -e ".* \\[\\[.*\\|' .. input .. '\\]\\].*"')
	local lines = vim.split(cmd, "\n")
	local cwd = vim.fn.getcwd()
	Header = ""
	Output = {}
	for _, v in ipairs(lines) do
		local file, sentince = string.match(v, "(.+):(.+) %[%[") -- we are grabbing the file and the string tagged
		local _, _, match = string.match(Header, "### %[(.+)%]") -- we are grapping the filename form the markdown link
		if file == nil then
			goto continue
		end

		if not (match == file) or (Header == "") then
			Header = string.format('### [%s]("%s/%s")', file, cwd, file)
			table.insert(Output, Header)
		end

		sentince = string.format('  - "%s"', sentince)
		table.insert(Output, sentince)
		::continue::
	end
	vim.cmd("vsplit | enew | setfiletype markdown | set fileencoding=utf-8")
	local bufnr = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, Output)
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
