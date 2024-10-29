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

local get_alias = function()
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

local alias_match = function(input)
	-- TODO: need to Make the pattern configurable
	-- TODO: make the patern go full line
	local cmd = vim.fn.system("rg " .. M.config.path .. ' -e ".*\\[\\[.*\\|' .. input .. '\\]\\].*"')
	local lines = vim.split(cmd, "\n")
	return lines
end

local create_reference_document = function(lines)
	local header = ""
	local output = {}
	for _, line in pairs(lines) do
		local full_line = string.gsub(line, "%[%[.+%]%]", "")
		local file_path, sentince = string.match(full_line, "(.+):(.+)") -- we are grabbing the filename and the tagged line
		local file_path_match = string.match(header, "### %[(.+)%]") -- we are grabbing the filename form the markdown link

		if file_path_match ~= file_path and file_path ~= nil then
			header = string.format('### [%s]("%s")', file_path, file_path)
			table.insert(output, header)
		end

		if sentince ~= nil then
			sentince = string.format('  - "%s"', sentince)
			table.insert(output, sentince)
		end
	end
	return output
end
local generate_reference_list = function(input)
	local lines = alias_match(input)
	local ref_content = create_reference_document(lines)
	create_tmp_buf(ref_content)
end

M.pick_alias = function(opts)
	pickers
		.new(opts, {
			finder = finders.new_table({
				unpack(get_alias()),
			}),
			sorter = config.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					generate_reference_list(selection.value)
				end)
				return true
			end,
		})
		:find()
end

--NOTE: Uncomment lines below to hot-reload test

--M.setup({ path = "/Users/anthonymirville/Projects/Life" })
--M.pick_alias({})

return M
