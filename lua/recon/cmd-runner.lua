local recon = require("recon")
local utils = require("recon.utils")

local M = {}

function M.find_usable_terminal()
	local pane_id, curr_pane_idx

	local pane_list, _, _ = utils.os_cmd_run({
		"tmux",
		"list-panes",
		"-F",
		"#{pane_index}:#{pane_active}:#{pane_current_command}",
	}, vim.loop.cwd())

	for _, line in pairs(pane_list) do
		local pane_info = utils.split_string(line, ":")
		local idx = pane_info[1]
		local active = pane_info[2]
		local cmd = pane_info[3]

		if cmd == "zsh" then
			pane_id = idx
		elseif active == "1" then
			curr_pane_idx = idx
		end
	end

	if not pane_id then
		pane_id = nil
	end

	return { pane_id = pane_id, curr_pane_idx = curr_pane_idx }
end

function M.run_recon_cmd(cmd_idx, ...)
	local id_table = M.find_usable_terminal()
	local pane_id = id_table.pane_id
	local curr_pane_id = id_table.curr_pane_idx
	local cmd = recon.get_term_config().cmds[cmd_idx]

	if pane_id == nil then
		vim.cmd.w()
		vim.cmd.split()
		vim.cmd.wincmd("J")
		vim.api.nvim_win_set_height(0, 20)
		vim.wo.winfixheight = true
		vim.cmd.term(cmd)
		vim.cmd.startinsert()
	else
		M.go_to_split_terminal(pane_id)
		if cmd ~= nil then
			M.send_command(pane_id, "clear", ...)
			M.send_command(pane_id, cmd, ...)
			M.go_to_split_terminal(curr_pane_id)
		end
	end
end

function M.send_command(idx, cmd, ...)
	local _ = utils.os_cmd_run({
		"tmux",
		"send-keys",
		"-t",
		idx,
		string.format(cmd, ...),
		"C-m",
	}, vim.loop.cwd())
end

function M.go_to_split_terminal(idx)
	local _, ret, stderr = utils.os_cmd_run({
		"tmux",
		"select-pane",
		"-t",
		idx,
	}, vim.loop.cwd())

	if ret ~= 0 then
		error("Failed to go to terminal." .. stderr)
	end
end

return M
