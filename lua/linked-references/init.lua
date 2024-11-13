local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local config = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local M = {}

local function map(mode, combo, mapping, desc)
	if combo then
		vim.keymap.set(mode, combo, mapping, { silent = true, desc = desc })
	end
end

function M.setup(opts)
	local default = {
		path = ".",
		front_matter = "aliases",
		mappings = {
			search_alias = "<leader>;",
		},
	}
	M.config = vim.tbl_extend("keep", opts or {}, default)
	map("n", M.config.mappings.search_alias, M.pick_alias, "Search alias")
end
-- this grabs alll the front matter fields and values from all files in M.config.path
local get_front_matter = function()
	-- TODO: Make the front matter and the datatype customizable
	local cmd = "find "
		.. M.config.path
		.. ' -type f -name "*.md" | xargs -I {} yq -o=json -I=0 --front-matter=extract . {}'
	local output = vim.fn.system(cmd)
	local front_matter_obj = {}
	local json_string = vim.split(output, "\n", { plain = true, trimempty = true })
	for _, line in pairs(json_string) do
		if line ~= "null" then
			local entry = vim.json.decode(line)
			table.insert(front_matter_obj, entry)
		end
	end
	return front_matter_obj
end

-- create an table with document id and alias name
local create_fm_list = function(front_matter_obj)
	local alias_obj = {}
	for _, f_m in pairs(front_matter_obj) do
		if f_m.aliases ~= nil and next(f_m.aliases) ~= nil then
			if #f_m.aliases == 1 then
				table.insert(alias_obj, { alias_name = f_m.aliases[1], id = f_m.id })
			else
				for _, alias in pairs(f_m.aliases) do
					table.insert(alias_obj, { alias_name = alias, id = f_m.id })
				end
			end
		end
	end
	return alias_obj
end
local alias_match = function(input)
	-- TODO: need to Make the pattern configurable
	-- TODO: make the pattern go full line
	M._alias_name = input.alias_name
	M._wiki_tag = "[[" .. input.id .. "|" .. input.alias_name .. "]]"

	local cmd = vim.fn.system(
		"rg -l -i " .. M.config.path .. ' -e  ".* \\[\\[' .. input.id .. "\\|" .. input.alias_name .. '\\]\\].*"'
	)
	local lines = vim.split(cmd, "\n", { trimempty = true })
	return lines
end

---@param content string
local create_tmp_buf = function(content)
	-- BUG: need to make the file be able to just quit with q not q!
	-- BUG: when a buffer already exists this fails and opens a new empty buffer need to check if buffer already exists.
	if #content ~= 0 then
		vim.cmd("vsplit | enew | e " .. M._alias_name .. "| setfiletype markdown | set fileencoding=utf-8")
		local bufnr = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
		return
	end

	vim.notify_once("Looks You haven't written anything on this topics.", vim.log.levels.INFO)
end

local generate_reference_list = function(input)
	M._alias_name = input
	local lines = alias_match(M._alias_name)
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
--M.pick_alias()

return M
