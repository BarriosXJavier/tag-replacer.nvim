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

	return vim.api.nvim_buf_attach(bufnr, false, {
		on_bytes = function(_, _, _, start_row, start_col, _, _, _, new_end_col)
			-- Get the current line
			local line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]
			if not line then
				return
			end

			-- Extract the cursor position inside the line
			local cursor_col = start_col + new_end_col

			-- Get substring around cursor to detect tag modification
			local before_cursor = line:sub(1, cursor_col)
			local after_cursor = line:sub(cursor_col + 1)

			-- Check if we're editing inside a tag
			local tag_prefix = before_cursor:match(".*</?([%w%-]*)$")
			if not tag_prefix then
				return
			end

			-- Get the complete tag name
			local tag_suffix = after_cursor:match("^([%w%-]*)[^>]*>")
			if not tag_suffix then
				return
			end

			local tag_name = tag_prefix .. tag_suffix
			if #tag_name == 0 then
				return
			end

			-- Get all buffer content
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

			-- Find and update corresponding tag
			for i, content in ipairs(lines) do
				if i - 1 ~= start_row then -- Skip the current line
					if content:match("</?%" .. tag_name .. "[^>]*>") then
						local new_content = content
						if content:match("<" .. tag_name .. "[^>]*>") then
							new_content = content:gsub("<" .. tag_name .. "([^>]*)>", "<" .. tag_name .. "%1>")
						elseif content:match("</" .. tag_name .. ">") then
							new_content = content:gsub("</" .. tag_name .. ">", "</" .. tag_name .. ">")
						end
						if new_content ~= content then
							vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, { new_content })
						end
					end
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
