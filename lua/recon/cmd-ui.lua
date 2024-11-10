local recon = require("recon")
local popup = require("plenary.popup")
local utils = require("recon.utils")

local M = {}

Recon_cmd_win_id = nil
Recon_cmd_bufh = nil

local function create_window()
	vim.api.nvim_set_hl(0, "ReconWindow", { fg = "#adb8b8", bg = "none" }) -- window background
	vim.api.nvim_set_hl(0, "ReconBorder", { fg = "#073642" }) -- border color
	vim.api.nvim_set_hl(0, "ReconTitle", { fg = "#adb8b8", bold = true }) -- title color

	local config = recon.get_menu_config()
	local width = config.width or 60
	local height = config.height or 10
	local borderchars = config.borderchars or { "━", "┃", "━", "┃", "┏", "┓", "┛", "┗" }
	local bufnr = vim.api.nvim_create_buf(false, false)

	local Recon_cmd_win_id, _ = popup.create(bufnr, {
		title = "Recon Commands  ",
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
		win_id = Recon_cmd_win_id,
	}
end

local function close_menu()
	vim.api.nvim_win_close(Recon_cmd_win_id, true)

	Recon_cmd_win_id = nil
	Recon_cmd_bufh = nil
end

function M.toggle_quick_menu()
	if Recon_cmd_win_id ~= nil and vim.api.nvim_win_is_valid(Recon_cmd_win_id) then
		close_menu()
		return
	end

	local win_info = create_window()
	local contents = {}
	local global_config = recon.get_global_settings()

	Recon_cmd_win_id = win_info.win_id
	Recon_cmd_bufh = win_info.bufnr

	for idx, cmd in pairs(recon.get_term_config().cmds) do
		contents[idx] = cmd
	end

	vim.api.nvim_win_set_option(Recon_cmd_win_id, "number", true)
	vim.api.nvim_buf_set_name(Recon_cmd_bufh, "Recon Commands")
	vim.api.nvim_buf_set_lines(Recon_cmd_bufh, 0, #contents, false, contents)
	vim.api.nvim_buf_set_option(Recon_cmd_bufh, "filetype", "recon")
	vim.api.nvim_buf_set_option(Recon_cmd_bufh, "buftype", "acwrite")
	vim.api.nvim_buf_set_option(Recon_cmd_bufh, "bufhidden", "delete")
	vim.api.nvim_buf_set_keymap(
		Recon_cmd_bufh,
		"n",
		"q",
		"<Cmd>lua require('recon.cmd-ui').toggle_quick_menu()<CR>",
		{ silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		Recon_cmd_bufh,
		"n",
		"<ESC>",
		"<Cmd>lua require('recon.cmd-ui').toggle_quick_menu()<CR>",
		{ silent = true }
	)
	vim.cmd(string.format("autocmd BufWriteCmd <buffer=%s> lua require('recon.cmd-ui').on_menu_save()", Recon_cmd_bufh))
	if global_config.save_on_change then
		vim.cmd(
			string.format(
				"autocmd TextChanged,TextChangedI <buffer=%s> lua require('recon.cmd-ui').on_menu_save()",
				Recon_cmd_bufh
			)
		)
	end
	vim.cmd(string.format("autocmd BufModifiedSet <buffer=%s> set nomodified", Recon_cmd_bufh))
end

function M.emit_changed()
	if recon.get_global_settings().save_on_change then
		recon.save()
	end
end

function M.set_cmd_list(new_list)
	for k in pairs(recon.get_term_config().cmds) do
		recon.get_term_config().cmds[k] = nil
	end
	for k, v in pairs(new_list) do
		recon.get_term_config().cmds[k] = v
	end
	M.emit_changed()
end

local function get_menu_items()
	local lines = vim.api.nvim_buf_get_lines(Recon_cmd_bufh, 0, -1, true)
	local indices = {}

	for _, line in pairs(lines) do
		if not utils.is_white_space(line) then
			table.insert(indices, line)
		end
	end

	return indices
end

function M.on_menu_save()
	M.set_cmd_list(get_menu_items())
end

return M
