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
	local open_pattern = "<" .. from_tag .. "([^>]*)>"
	local close_pattern = "</" .. from_tag .. ">"

	local result = text:gsub(open_pattern, "<" .. to_tag .. "%1>")
	result = result:gsub(close_pattern, "</" .. to_tag .. ">")

	return result
end

local function replace_tag_under_cursor(to_tag)
	if not is_valid_tag_name(to_tag) then
		vim.notify("Invalid tag name", vim.log.levels.ERROR)
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]

	if not line then
		return
	end

	local before_cursor = line:sub(1, col)
	local after_cursor = line:sub(col + 1)

	local open_tag_name = before_cursor:match(".*<([%w%d%-]+)[^>]*>")
	local close_tag_name = before_cursor:match(".*</([%w%d%-]+)>")

	if open_tag_name then
		local new_line = before_cursor:gsub("<" .. open_tag_name .. "([^>]*)>", "<" .. to_tag .. "%1>") .. after_cursor
		vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { new_line })
	elseif close_tag_name then
		local new_line = before_cursor:gsub("</" .. close_tag_name .. ">", "</" .. to_tag .. ">") .. after_cursor
		vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { new_line })
	end
end

local function sync_partner_tag()
	local bufnr = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_attach(bufnr, false, {
		on_lines = function(_, _, _, start_row, _, _)
			local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, vim.api.nvim_buf_line_count(bufnr), false)
			for _, line in ipairs(lines) do
				local open_tag = line:match("<([%w%d%-]+)")
				if open_tag then
					local close_tag_pattern = "</" .. open_tag .. ">"
					for i = start_row, vim.api.nvim_buf_line_count(bufnr) do
						local close_line = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
						if close_line and close_line:match(close_tag_pattern) then
							local updated_close = close_line:gsub(close_tag_pattern, "</" .. open_tag .. ">")
							vim.api.nvim_buf_set_lines(bufnr, i, i + 1, false, { updated_close })
							break
						end
					end
				end
			end
		end,
	})
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

	vim.api.nvim_create_user_command("ReplaceUnderCursor", function(opts)
		local args = vim.split(opts.args, " ")
		if #args ~= 1 then
			vim.notify("Usage: ReplaceUnderCursor to_tag", vim.log.levels.ERROR)
			return
		end
		replace_tag_under_cursor(args[1])
	end, {
		nargs = "1",
		desc = "Replace the HTML-style tag under the cursor",
	})

	sync_partner_tag()
end

return M
