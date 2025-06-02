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
		wiki_tag_format = "[[<id>|<alias>]]",
		mappings = {
			search_alias = "<leader>;",
		},
	}
	M.config = vim.tbl_extend("keep", opts or {}, default)
	map("n", M.config.mappings.search_alias, M.pick_alias, "Search alias test")
end

-- this grabs alll the front matter fields and values from all files in M.config.path
local get_front_matter = function()
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
local format_wiki_tag = function(entry)
	local format = M.config.wiki_tag_format
	if type(format) == "function" then
		return format(entry)
	elseif type(format) == "string" then
		return format:gsub("<id>", entry.id):gsub("<alias>", entry.alias_name)
	else
		error("wiki_tag_format must be a string or function")
	end
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
	M._wiki_tags = ""
	local lines = {}
	local cmd
	if #input > 1 then
		for _, obj in ipairs(input) do
			M._wiki_tags = M._wiki_tags .. format_wiki_tag(obj.value) .. ","
			cmd = vim.fn.system(
				"rg -l -i "
					.. M.config.path
					.. ' -e  ".* \\[\\['
					.. obj.value.id
					.. "\\|"
					.. obj.value.alias_name
					.. '\\]\\].*"'
			)
			if #vim.split(cmd, "\n", { trimempty = true }) ~= 0 then
				table.insert(lines, vim.split(cmd, "\n", { trimempty = true }))
			end
		end
		return lines
	end
	input = input[1]
	M._alias_name = input.value.alias_name
	M._wiki_tags = "[[" .. input.value.id .. "|" .. input.value.alias_name .. "]]"

	cmd = vim.fn.system(
		"rg -l -i "
			.. M.config.path
			.. ' -e  ".* \\[\\['
			.. input.value.id
			.. "\\|"
			.. input.value.alias_name
			.. '\\]\\].*"'
	)
	lines = vim.split(cmd, "\n", { trimempty = true })
	return lines
end

---@param content string
local create_tmp_buf = function(content)
	local alias_name = M._alias_name or "Group Search"

	-- BUG: need to make the file be able to just quit with q not q!
	if #content ~= 0 then
		vim.cmd("vsplit |e " .. alias_name .. "| setfiletype markdown | set fileencoding=utf-8")
		local bufnr = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
		return
	end

	vim.notify_once("Looks You haven't written anything on this topics.", vim.log.levels.INFO)
end

---@param files string[]
local de_dup = function(files)
	local set = {}
	for _, file in pairs(files) do
		set[file] = true
	end
	return set
end

local get_matches = function(f)
	local wiki_tag = M._wiki_tags
	local markdown = ""
	local file_list = {}
	local files = de_dup(vim.iter(f):flatten():totable())

	for file, _ in pairs(files) do
		table.insert(file_list, file)
	end
	file_flag = table.concat(file_list, ",")

	local cmd = "parser parse --tag='" .. wiki_tag .. "' --files='" .. vim.trim(file_flag) .. "'"
	vim.fn.jobstart(cmd, {
		stdout_buffered = true, -- Set to true for buffered output
		on_stdout = function(_, data)
			if data then
				vim.schedule(function()
					markdown = data
				end)
			end
		end,
		on_stderr = function(_, data)
			if data ~= "" then
				vim.schedule(function()
					print("Error:", table.concat(data, "\n"))
				end)
			end
		end,
		on_exit = function(_)
			vim.schedule(function()
				create_tmp_buf(markdown)
			end)
		end,
	})
end

local generate_reference_list = function(input)
	local files = alias_match(input)
	get_matches(files)
end

M.pick_alias = function(opts)
	pickers
		.new(opts, {

			prompt_title = "Tag List",
			finder = finders.new_table({
				results = create_fm_list(get_front_matter()),
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry.alias_name,
						ordinal = entry.alias_name,
					}
				end,
			}),
			sorter = config.generic_sorter(opts),
			attach_mappings = function(_, map)
				local function on_select(prompt_bufnr)
					local picker = action_state.get_current_picker(prompt_bufnr)
					local selections = picker:get_multi_selection()

					if vim.tbl_isempty(selections) then
						table.insert(selections, action_state.get_selected_entry())
					end
					actions.close(prompt_bufnr)
					generate_reference_list(selections)
				end
				map("i", "<CR>", on_select)
				map("n", "<CR>", on_select)
				map("i", "<Tab>", actions.toggle_selection + actions.move_selection_worse)
				map("n", "<Tab>", actions.toggle_selection + actions.move_selection_worse)
				map("i", "<S-Tab>", actions.toggle_selection + actions.move_selection_better)
				map("n", "<S-Tab>", actions.toggle_selection + actions.move_selection_better)

				return true
			end,
		})
		:find()
end

-- Make the function available for :lua calls
-- NOTE: Uncomment lines below to hot-reload test
--M.setup({ path = "/Users/anthonymirville/Projects/Life" })
--M.pick_alias()

return M
