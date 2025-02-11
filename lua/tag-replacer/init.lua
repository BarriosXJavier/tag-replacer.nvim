local M = {}

local function replace_tags(text, from_tag, to_tag)
	-- Escape special characters in the tag names
	from_tag = from_tag:gsub("[%-%.%+%[%]%(%)%$%^%%%?%*]", "%%%1")

	-- patterns for opening and closing tags
	local open_pattern = "<" .. from_tag .. "([^>]*)>"
	local close_pattern = "</" .. from_tag .. ">"

	-- Replace opening and closing tags
	local result = text:gsub(open_pattern, "<" .. to_tag .. "%1>")
	result = result:gsub(close_pattern, "</" .. to_tag .. ">")

	return result
end

-- replace tags in the entire buffer
function M.replace_tags_in_buffer(from_tag, to_tag)
	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local new_lines = {}

	for _, line in ipairs(lines) do
		table.insert(new_lines, replace_tags(line, from_tag, to_tag))
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
end

-- replace tags in visual selection
function M.replace_tags_in_selection(from_tag, to_tag)
	local bufnr = vim.api.nvim_get_current_buf()
	local start_pos = vim.api.nvim_buf_get_mark(bufnr, "<")
	local end_pos = vim.api.nvim_buf_get_mark(bufnr, ">")

	-- Get the selected lines
	local lines = vim.api.nvim_buf_get_lines(bufnr, start_pos[1] - 1, end_pos[1], false)
	local new_lines = {}

	for _, line in ipairs(lines) do
		table.insert(new_lines, replace_tags(line, from_tag, to_tag))
	end

	-- Replace the selected lines with the modified content
	vim.api.nvim_buf_set_lines(bufnr, start_pos[1] - 1, end_pos[1], false, new_lines)
end

-- replace tags in the entire buffer
function M.setup()
	vim.api.nvim_create_user_command("ReplaceTag", function(opts)
		local args = vim.split(opts.args, " ")
		if #args ~= 2 then
			vim.notify("Usage: ReplaceTag from_tag to_tag", vim.log.levels.ERROR)
			return
		end
		M.replace_tags_in_buffer(args[1], args[2])
	end, {
		nargs = "+",
		desc = "Replace HTML-style tags throughout the buffer",
	})

	-- Command to replace tags in visual selection
	vim.api.nvim_create_user_command("ReplaceTagVisual", function(opts)
		local args = vim.split(opts.args, " ")
		if #args ~= 2 then
			vim.notify("Usage: ReplaceTagVisual from_tag to_tag", vim.log.levels.ERROR)
			return
		end
		M.replace_tags_in_selection(args[1], args[2])
	end, {
		nargs = "+",
		range = true,
		desc = "Replace HTML-style tags in visual selection",
	})
end

return M
