local utils = require("recon.utils")
local Path = require("plenary.path")

local data_path = vim.fn.stdpath("data")
local cache_config = string.format("%s/recon.json", data_path)

local M = {}

local recon_naissance = vim.api.nvim_create_augroup("recon_naissance", { clear = true })

vim.api.nvim_create_autocmd({ "BufLeave", "VimLeave" }, {
	callback = function()
		require("recon.mark").store_offset()
	end,
	group = recon_naissance,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = "recon",
	group = recon_naissance,

	callback = function()
		vim.keymap.set("n", "<C-V>", function()
			local curline = vim.api.nvim_get_current_line()
			local working_directory = vim.fn.getcwd() .. "/"
			vim.cmd("vs")
			vim.cmd("e " .. working_directory .. curline)
		end, { buffer = true, noremap = true, silent = true })
	end,
})

ReconConfig = ReconConfig or {}

local function expand_dir(config)
	local projects = config.projects or {}
	for k in pairs(projects) do
		local expanded_path = Path.new(k):expand()
		projects[expanded_path] = projects[k]
		if expanded_path ~= k then
			projects[k] = nil
		end
	end

	return config
end

local function merge_table_impl(t1, t2)
	for k, v in pairs(t2) do
		if type(v) == "table" then
			if type(t1[k]) == "table" then
				merge_table_impl(t1[k], v)
			else
				t1[k] = v
			end
		else
			t1[k] = v
		end
	end
end

local function merge_tables(...)
	local out = {}
	for i = 1, select("#", ...) do
		merge_table_impl(out, select(i, ...))
	end
	return out
end

local function read_config(local_config)
	return vim.json.decode(Path:new(local_config):read())
end

local function ensure_correct_config(config)
	local projects = config.projects
	local mark_key = utils.project_key()
	if projects[mark_key] == nil then
		projects[mark_key] = {
			mark = { marks = {} },
			term = {
				cmds = {},
			},
		}
	end

	local proj = projects[mark_key]
	if proj.mark == nil then
		proj.mark = { marks = {} }
	end

	if proj.term == nil then
		proj.term = { cmds = {} }
	end

	local marks = proj.mark.marks

	for idx, mark in pairs(marks) do
		if type(mark) == "string" then
			mark = { filename = mark }
			marks[idx] = mark
		end

		marks[idx].filename = utils.normalize_path(mark.filename)
	end

	return config
end

function M.save()
	M.refresh_projects_b4update()

	Path:new(cache_config):write(vim.fn.json_encode(ReconConfig), "w")
end

function M.get_mark_config()
	return ensure_correct_config(ReconConfig).projects[utils.project_key()].mark
end

function M.get_global_settings()
	return ReconConfig.global_settings
end

function M.refresh_projects_b4update()
	local cwd = utils.project_key()
	local current_p_config = {
		projects = {
			[cwd] = ensure_correct_config(ReconConfig).projects[cwd],
		},
	}

	ReconConfig.projects = nil

	local ok2, c_config = pcall(read_config, cache_config)

	if not ok2 then
		c_config = { projects = {} }
	end

	c_config = { projects = c_config.projects }

	c_config.projects[cwd] = nil

	local complete_config = merge_tables(ReconConfig, expand_dir(c_config), expand_dir(current_p_config))

	ensure_correct_config(complete_config)

	ReconConfig = complete_config
end

function M.get_menu_config()
	return ReconConfig.menu or {}
end

function M.setup(config)
	if not config then
		config = {}
	end

	local ok2, c_config = pcall(read_config, cache_config)

	if not ok2 then
		c_config = {}
	end

	local complete_config = merge_tables({
		projects = {},
		global_settings = {
			["save_on_toggle"] = false,
			["save_on_change"] = true,
			["enter_on_sendcmd"] = false,
			["tmux_autoclose_windows"] = false,
			["excluded_filetypes"] = { "recon" },
			["mark_branch"] = false,
			["tabline"] = true,
			["tabline_suffix"] = "   ",
			["tabline_prefix"] = "   ",
		},
	}, expand_dir(c_config), expand_dir(config))

	ensure_correct_config(complete_config)

    if complete_config.global_settings.tabline then
        require("recon.tabline").setup(complete_config)
    end

	ReconConfig = complete_config
end

M.setup()

return M
