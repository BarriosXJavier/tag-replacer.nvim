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

	vim.api.nvim_buf_attach(bufnr, false, {
		on_bytes = function(_, _, _, start_row, start_col, _, _, _, new_end_col)
			vim.schedule(function()
				-- Get current line
				local line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]
				if not line then
					return
				end

				-- Try to find any tag at cursor position
				local open_tag = line:match("<([%w%-]+)")
				local close_tag = line:match("</([%w%-]+)>")
				local tag_name = open_tag or close_tag

				if not tag_name then
					return
				end

				-- Get all lines and join them
				local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

				-- Find matching tag in other lines
				for i, other_line in ipairs(lines) do
					if i - 1 ~= start_row then -- Skip current line
						if close_tag then
							-- If we're editing closing tag, look for opening tag
							if other_line:match("<" .. tag_name .. "[^>]*>") then
								local new_line =
									other_line:gsub("<" .. tag_name .. "([^>]*)>", "<" .. tag_name .. "%1>")
								vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, { new_line })
							end
						elseif open_tag then
							-- If we're editing opening tag, look for closing tag
							if other_line:match("</" .. tag_name .. ">") then
								local new_line = other_line:gsub("</" .. tag_name .. ">", "</" .. tag_name .. ">")
								vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, { new_line })
							end
						end
					end
				end
			end)
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
