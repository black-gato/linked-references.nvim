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

local alias_match = function(input)
	-- TODO: need to Make the pattern configurable
	-- TODO: make the pattern go full line
	local cmd = vim.fn.system("rg -n -i " .. M.config.path .. ' -e  ".*\\[\\[.*\\|' .. input .. '\\]\\].*"')
	local lines = vim.split(cmd, "\n", { trimempty = true })
	return lines
end

local create_reference_document = function(lines)
	local header = ""
	local output = {}
	for _, line in pairs(lines) do
		-- local pattern = "%[%[[^|]-%|" .. M._alias_name .. "%]%]"
		-- local full_line = string.gsub(line, pattern, "") BUG: don't use use this unless you want to remove the tag in the sentence

		local file_path, line_num, sentince = string.match(line, "(.+%.md):(.+):(.+)") -- we are grabbing the filename and the tagged line
		local file_path_match = string.match(header, "### %[(.+)%]") -- we are grabbing the filename form the markdown link
		--print(vim.inspect("Path: " .. file_path .. ", Line Num:" .. line_num .. ", sentince: " .. sentince))

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

---@param content table
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
