local recon = require("recon")
local popup = require("plenary.popup")
local Marked = require("recon.mark")
local utils = require("recon.utils")

local M = {}

local function close_menu(force_save)
	force_save = force_save or false
	local global_config = recon.get_global_settings()

	if global_config.save_on_toggle or force_save then
		require("recon.ui").on_menu_save()
	end

	vim.api.nvim_win_close(Recon_win_id, true)

	Recon_win_id = nil
	Recon_bufh = nil
end

local function create_window()
    vim.api.nvim_set_hl(0, 'ReconWindow', { fg = '#adb8b8', bg = 'none' })  -- window background
    vim.api.nvim_set_hl(0, 'ReconBorder', { fg = '#073642' })  -- border color
    vim.api.nvim_set_hl(0, 'ReconTitle', { fg = '#adb8b8', bold = true })  -- title color

	local config = recon.get_menu_config()
	local width = config.width or 60
	local height = config.height or 10
	local borderchars = config.borderchars or { "━", "┃", "━", "┃", "┏", "┓", "┛", "┗" }
	local bufnr = vim.api.nvim_create_buf(false, false)

	local Recon_win_id, win = popup.create(bufnr, {
		title = "Recon Marks  ",
		highlight = "ReconWindow",
		line = math.floor(((vim.o.lines - height) / 2) - 1),
		col = math.floor((vim.o.columns - width) / 2),
		minwidth = width,
		minheight = height,
		borderchars = borderchars,
        borderhighlight = "ReconBorder",
        titlehighlight = "ReconTitle",
	})

	return {
		bufnr = bufnr,
		win_id = Recon_win_id,
	}
end

function M.toggle_quick_menu()
	if Recon_win_id ~= nil and vim.api.nvim_win_is_valid(Recon_win_id) then
		close_menu()
		return
	end

	local curr_file = utils.normalize_path(vim.api.nvim_buf_get_name(0))
	vim.cmd(
		string.format(
			"autocmd Filetype recon "
				.. "let path = '%s' | call clearmatches() | "
				.. "call search('\\V'.path.'\\$') | "
				.. "call matchadd('ReconCurrentFile', '\\V'.path.'\\$')",
			curr_file:gsub("\\", "\\\\")
		)
	)

	local win_info = create_window()
	local contents = {}
	local global_config = recon.get_global_settings()

	Recon_win_id = win_info.win_id
	Recon_bufh = win_info.bufnr

	for idx = 1, Marked.get_length() do
		local file = Marked.get_marked_file_name(idx)
		if file == "" then
			file = "(empty)"
		end
		contents[idx] = string.format("%s", file)
	end

	vim.api.nvim_win_set_option(Recon_win_id, "number", true)
	vim.api.nvim_buf_set_name(Recon_bufh, "Recon Marks")
	vim.api.nvim_buf_set_lines(Recon_bufh, 0, #contents, false, contents)
	vim.api.nvim_buf_set_option(Recon_bufh, "filetype", "recon")
	vim.api.nvim_buf_set_option(Recon_bufh, "buftype", "acwrite")
	vim.api.nvim_buf_set_option(Recon_bufh, "bufhidden", "delete")
	vim.api.nvim_buf_set_keymap(
		Recon_bufh,
		"n",
		"q",
		"<Cmd>lua require('recon.ui').toggle_quick_menu()<CR>",
		{ silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		Recon_bufh,
		"n",
		"<ESC>",
		"<Cmd>lua require('recon.ui').toggle_quick_menu()<CR>",
		{ silent = true }
	)
	vim.api.nvim_buf_set_keymap(Recon_bufh, "n", "<CR>", "<Cmd>lua require('recon.ui').select_menu_item()<CR>", {})
	vim.cmd(string.format("autocmd BufWriteCmd <buffer=%s> lua require('recon.ui').on_menu_save()", Recon_bufh))
	if global_config.save_on_change then
		vim.cmd(
			string.format(
				"autocmd TextChanged,TextChangedI <buffer=%s> lua require('recon.ui').on_menu_save()",
				Recon_bufh
			)
		)
	end
	vim.cmd(string.format("autocmd BufModifiedSet <buffer=%s> set nomodified", Recon_bufh))
	vim.cmd("autocmd BufLeave <buffer> ++nested ++once silent lua require('recon.ui').toggle_quick_menu()")
end

function M.nav_prev()
	local current_index = Marked.get_current_index()
	local number_of_items = Marked.get_length()

	if current_index == nil then
		current_index = number_of_items
	else
		current_index = current_index - 1
	end

	if current_index < 1 then
		current_index = number_of_items
	end

	M.nav_file(current_index)
end

function M.nav_next()
	local current_index = Marked.get_current_index()
	local number_of_items = Marked.get_length()

	if current_index == nil then
		current_index = 1
	else
		current_index = current_index + 1
	end

	if current_index > number_of_items then
		current_index = 1
	end
	M.nav_file(current_index)
end

local function get_or_create_buffer(filename)
	local buf_exists = vim.fn.bufexists(filename) ~= 0
	if buf_exists then
		return vim.fn.bufnr(filename)
	end

	return vim.fn.bufadd(filename)
end

function M.nav_file(id)
	local idx = Marked.get_index_of(id)

	local mark = Marked.get_marked_file(idx)
    if mark == nil then
        return
    end
	local filename = vim.fs.normalize(mark.filename)
	local buf_id = get_or_create_buffer(filename)
	local set_row = not vim.api.nvim_buf_is_loaded(buf_id)

	local old_bufnr = vim.api.nvim_get_current_buf()

	vim.api.nvim_set_current_buf(buf_id)
	vim.api.nvim_buf_set_option(buf_id, "buflisted", true)
	if set_row and mark.row and mark.col then
		vim.api.nvim_win_set_cursor(0, { mark.row, mark.col })
	end

	local old_bufinfo = vim.fn.getbufinfo(old_bufnr)
	if type(old_bufinfo) == "table" and #old_bufinfo >= 1 then
		old_bufinfo = old_bufinfo[1]
		local no_name = old_bufinfo.name == ""
		local one_line = old_bufinfo.linecount == 1
		local unchanged = old_bufinfo.changed == 0
		if no_name and one_line and unchanged then
			vim.api.nvim_buf_delete(old_bufnr, {})
		end
	end
end

function M.select_menu_item()
	local idx = vim.fn.line(".")
	close_menu(true)
	M.nav_file(idx)
end

local function get_menu_items()
	local lines = vim.api.nvim_buf_get_lines(Recon_bufh, 0, -1, true)
	local indices = {}

	for _, line in pairs(lines) do
		if not utils.is_white_space(line) then
			table.insert(indices, line)
		end
	end

	return indices
end

function M.on_menu_save()
	Marked.set_mark_list(get_menu_items())
end

return M
