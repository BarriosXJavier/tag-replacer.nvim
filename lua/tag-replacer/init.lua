local M = {}

local function is_valid_tag_name(tag)
	return type(tag) == "string" and tag:match("^[%w%d%-]+$") ~= nil
end

local function replace_tags(text, from_tag, to_tag)
	if not is_valid_tag_name(from_tag) or not is_valid_tag_name(to_tag) then
		vim.notify("Invalid tag name", vim.log.levels.ERROR)
		return text
	end
	from_tag = from_tag:gsub("[%-%.%+%[%]%(%)%$%^%%%?%*]", "%%%1")
	local open_pattern = "<" .. from_tag .. "([^/>]*)>"
	local close_pattern = "</" .. from_tag .. ">"
	local result = text:gsub(open_pattern, "<" .. to_tag .. "%1>")
	result = result:gsub(close_pattern, "</" .. to_tag .. ">")
	return result
end

local function sync_pair_tag()
	local bufnr = vim.api.nvim_get_current_buf()
	local namespace = vim.api.nvim_create_namespace("tag_sync")

	return vim.api.nvim_buf_attach(bufnr, false, {
		on_lines = function(_, bufnr, _, start_row, start_col, _, end_row, end_col, _)
			local line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]
			if not line then
				return
			end

			-- Check if we have a tag modification
			local modified_tag = line:match("</?([%w%-]+)")
			if not modified_tag then
				return
			end

			-- Get all buffer content
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			local content = table.concat(lines, "\n")

			-- Find the tag pair
			local opening_tag_pattern = "<" .. modified_tag .. "[^>]*>"
			local closing_tag_pattern = "</" .. modified_tag .. ">"

			-- Get positions of both tags
			local opening_pos = content:find(opening_tag_pattern)
			local closing_pos = content:find(closing_tag_pattern)

			if opening_pos and closing_pos then
				-- Extract the new tag name from the modified line
				local new_tag = line:match("</?([%w%-]+)")
				if new_tag and new_tag ~= modified_tag then
					-- Update both tags
					local new_content = content:gsub("<" .. modified_tag .. "([^>]*)>", "<" .. new_tag .. "%1>")
					new_content = new_content:gsub("</" .. modified_tag .. ">", "</" .. new_tag .. ">")

					-- Split and update buffer
					local new_lines = vim.split(new_content, "\n")
					vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
				end
			end
		end,
	})
end

local function replace_tags_in_selection(from_tag, to_tag)
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local start_row = start_pos[2] - 1
	local end_row = end_pos[2]

	local lines = vim.api.nvim_buf_get_lines(0, start_row, end_row, false)
	for i, line in ipairs(lines) do
		lines[i] = replace_tags(line, from_tag, to_tag)
	end
	vim.api.nvim_buf_set_lines(0, start_row, end_row, false, lines)
end

function M.setup()
	vim.api.nvim_create_user_command("ReplaceTag", function(opts)
		local args = vim.split(opts.args, " ")
		if #args ~= 2 then
			vim.notify("Usage: ReplaceTag from_tag to_tag", vim.log.levels.ERROR)
			return
		end
		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		for i, line in ipairs(lines) do
			lines[i] = replace_tags(line, args[1], args[2])
		end
		vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
	end, {
		nargs = "*",
		desc = "Replace HTML-style tags throughout the buffer",
	})

	vim.api.nvim_create_user_command("ReplaceTagInSelection", function(opts)
		local args = vim.split(opts.args, " ")
		if #args ~= 2 then
			vim.notify("Usage: ReplaceTagInSelection from_tag to_tag", vim.log.levels.ERROR)
			return
		end
		replace_tags_in_selection(args[1], args[2])
	end, {
		nargs = "*",
		range = true,
		desc = "Replace HTML-style tags within selection",
	})

	sync_pair_tag()
end

return M
