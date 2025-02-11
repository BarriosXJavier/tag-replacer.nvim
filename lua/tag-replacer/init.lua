local M = {}

-- Utility function to validate tag names
local function is_valid_tag_name(tag)
	return type(tag) == "string" and tag:match("^[%w%-]+$") ~= nil
end

local function replace_tags(text, from_tag, to_tag)
	if not is_valid_tag_name(from_tag) or not is_valid_tag_name(to_tag) then
		error("Invalid tag name provided")
	end

	from_tag = from_tag:gsub("[%-%.%+%[%]%(%)%$%^%%%?%*]", "%%%1")
	local open_pattern = "<" .. from_tag .. "([^>]*)>"
	local close_pattern = "</" .. from_tag .. ">"
	local result = text:gsub(open_pattern, "<" .. to_tag .. "%1>")
	result = result:gsub(close_pattern, "</" .. to_tag .. ">")
	return result
end

local function replace_tags_in_buffer(from_tag, to_tag)
	if not is_valid_tag_name(from_tag) or not is_valid_tag_name(to_tag) then
		vim.notify("Invalid tag name provided", vim.log.levels.ERROR)
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local new_lines = {}

	for _, line in ipairs(lines) do
		table.insert(new_lines, replace_tags(line, from_tag, to_tag))
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
end

local function replace_tag_under_cursor(to_tag)
	if not is_valid_tag_name(to_tag) then
		vim.notify("Invalid target tag name", vim.log.levels.ERROR)
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

	local open_tag_start, open_tag_end, open_tag_name = before_cursor:match(".*<([%w%-]+)([^>]*)>$")
	local close_tag_start, close_tag_end, close_tag_name = before_cursor:match(".*</([%w%-]+)>$")

	if open_tag_name then
		local new_line = before_cursor:gsub("<" .. open_tag_name .. "([^>]*)>$", "<" .. to_tag .. "%1>") .. after_cursor
		vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { new_line })
	elseif close_tag_name then
		local new_line = before_cursor:gsub("</" .. close_tag_name .. ">$", "</" .. to_tag .. ">") .. after_cursor
		vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { new_line })
	else
		vim.notify("No tag found under cursor", vim.log.levels.WARN)
	end
end

-- Store buffer attachments
M.attached_buffers = {}
M.sync_enabled = true

local function sync_partner_tag(bufnr)
	if M.attached_buffers[bufnr] then
		return
	end

	local is_updating = false

	local detach = vim.api.nvim_buf_attach(bufnr, false, {
		on_lines = function(_, _, _, start_row, _, end_row)
			if not M.sync_enabled or is_updating then
				return
			end

			is_updating = true

			local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, false)
			for _, line in ipairs(lines) do
				local open_tag = line:match("<([%w%-]+)")
				if open_tag then
					local close_tag_pattern = "</" .. open_tag .. ">"
					for i = start_row, vim.api.nvim_buf_line_count(bufnr) do
						local close_line = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
						if close_line and close_line:match(close_tag_pattern) then
							local updated_close = close_line:gsub(close_tag_pattern, "</" .. open_tag .. ">")
							pcall(vim.api.nvim_buf_set_lines, bufnr, i, i + 1, false, { updated_close })
							break
						end
					end
				end
			end

			is_updating = false
		end,
		on_detach = function()
			M.attached_buffers[bufnr] = nil
		end,
	})

	if detach then
		M.attached_buffers[bufnr] = true
	end
end

function M.toggle_sync()
	M.sync_enabled = not M.sync_enabled
	local status = M.sync_enabled and "enabled" or "disabled"
	vim.notify("Tag sync " .. status, vim.log.levels.INFO)
end

function M.detach_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if M.attached_buffers[bufnr] then
		vim.api.nvim_buf_detach(bufnr)
		M.attached_buffers[bufnr] = nil
		vim.notify("Detached tag sync from buffer " .. bufnr, vim.log.levels.INFO)
	end
end

function M.setup()
	vim.api.nvim_create_user_command("ReplaceTag", function(opts)
		local args = vim.split(opts.args, " ")
		if #args ~= 2 then
			vim.notify("Usage: ReplaceTag from_tag to_tag", vim.log.levels.ERROR)
			return
		end
		replace_tags_in_buffer(args[1], args[2])
	end, {
		nargs = "+",
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

	vim.api.nvim_create_user_command("ToggleTagSync", function()
		M.toggle_sync()
	end, {
		desc = "Toggle tag synchronization",
	})

	vim.api.nvim_create_user_command("DetachTagSync", function()
		M.detach_buffer()
	end, {
		desc = "Detach tag synchronization from current buffer",
	})

	-- Initialize sync for current buffer
	sync_partner_tag(vim.api.nvim_get_current_buf())
end

return M
