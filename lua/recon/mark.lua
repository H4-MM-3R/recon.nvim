local recon = require("recon")
local utils = require("recon.utils")

local M = {}
local callbacks = {}

local function filter_filetype()
	local current_filetype = vim.bo.filetype
	local excluded_filetypes = recon.get_global_settings().excluded_filetypes

	if current_filetype == "recon" then
		error("You can't add recon to the recon")
		return
	end

	if vim.tbl_contains(excluded_filetypes, current_filetype) then
		error('This filetype cannot be added or is included in the "excluded_filetypes" option')
		return
	end
end

local function get_buf_name(id)
	if id == nil then
		return utils.normalize_path(vim.api.nvim_buf_get_name(0))
	elseif type(id) == "string" then
		return utils.normalize_path(id)
	end

	local idx = M.get_index_of(id)
	if M.valid_index(idx) then
		return M.get_marked_file_name(idx)
	end

	return ""
end

local function validate_buf_name(buf_name)
	if buf_name == "" or buf_name == nil then
		error("Couldn't find a valid file name to mark, sorry.")
		return
	end
end

local function get_first_empty_slot()
	for idx = 1, M.get_length() do
		local filename = M.get_marked_file_name(idx)
		if filename == "" then
			return idx
		end
	end

	return M.get_length() + 1
end

local function create_mark(filename)
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	return {
		filename = filename,
		row = cursor_pos[1],
		col = cursor_pos[2],
	}
end

local function emit_changed()
	local global_settings = recon.get_global_settings()

	if global_settings.save_on_change then
		recon.save()
	end

	if global_settings.tabline then
		vim.cmd.redrawt()
	end

	if not callbacks["changed"] then
		return
	end

	for  cb in pairs(callbacks["changed"]) do
		cb()
	end
end

function M.remove_empty_tail(_emit_on_changed)
	_emit_on_changed = _emit_on_changed == nil or _emit_on_changed
	local config = recon.get_mark_config()
	local found = false

	for i = M.get_length(), 1, -1 do
		local filename = M.get_marked_file_name(i)
		if filename ~= "" then
			return
		end

		if filename == "" then
			table.remove(config.marks, i)
			found = found or _emit_on_changed
		end
	end

	if found then
		emit_changed()
	end
end

function M.add_file(file_name_or_buf_id)
	filter_filetype()
	local buf_name = get_buf_name(file_name_or_buf_id)

	validate_buf_name(buf_name)

	local found_idx = get_first_empty_slot()
	recon.get_mark_config().marks[found_idx] = create_mark(buf_name)
	M.remove_empty_tail(false)
	emit_changed()
end

function M.set_mark_list(new_list)
	local config = recon.get_mark_config()

	for k, v in pairs(new_list) do
		if type(v) == "string" then
			local mark = M.get_marked_file(v)
			if not mark then
				mark = create_mark(v)
			end

			new_list[k] = mark
		end
	end

	config.marks = new_list
	emit_changed()
end

local function maxn(t)
    local max_index = 0
    for k, _ in pairs(t) do
        if type(k) == "number" and k > max_index then
            max_index = k
        end
    end
    return max_index
end

function M.get_length(marks)
	if marks == nil then
		marks = recon.get_mark_config().marks
	end
	return maxn(marks)
end

function M.get_index_of(item, marks)
	if item == nil then
		error("You have provided a nil value to Recon, please provide a string rep of the file or the file idx.")
		return
	end

	if type(item) == "string" then
		local relative_item = utils.normalize_path(item)
		if marks == nil then
			marks = recon.get_mark_config().marks
		end
		for idx = 1, M.get_length(marks) do
			if marks[idx] and marks[idx].filename == relative_item then
				return idx
			end
		end

		return nil
	end

	if vim.g.manage_a_mark_zero_index then
		item = item + 1
	end

	if item <= M.get_length() and item >= 1 then
		return item
	end

	return nil
end

function M.get_marked_file(idxOrName)
	if type(idxOrName) == "string" then
		idxOrName = M.get_index_of(idxOrName)
	end
	return recon.get_mark_config().marks[idxOrName]
end

function M.get_marked_file_name(idx, marks)
	local mark
	if marks ~= nil then
		mark = marks[idx]
	else
		mark = recon.get_mark_config().marks[idx]
	end
	return mark and mark.filename
end

function M.get_current_index()
	return M.get_index_of(vim.api.nvim_buf_get_name(0))
end

function M.store_offset()
    local marks = recon.get_mark_config().marks
    local buf_name = get_buf_name()
    local idx = M.get_index_of(buf_name, marks)
    if not M.valid_index(idx, marks) then
        return
    end

    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    marks[idx].row = cursor_pos[1]
    marks[idx].col = cursor_pos[2]

	emit_changed()
end

function M.valid_index(idx, marks)
	return idx ~= nil and idx <= M.get_length(marks) and idx >= 1
end

return M
