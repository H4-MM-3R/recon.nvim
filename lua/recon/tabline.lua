local M = {}

local function get_color(group, attr)
	return vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(group)), attr)
end

local function shorten_filenames(filenames)
	local shortened = {}

	local counts = {}
	for _, file in ipairs(filenames) do
		local name = vim.fn.fnamemodify(file.filename, ":t")
		counts[name] = (counts[name] or 0) + 1
	end

	for _, file in ipairs(filenames) do
		local name = vim.fn.fnamemodify(file.filename, ":t")

		if counts[name] == 1 then
			table.insert(shortened, { filename = vim.fn.fnamemodify(name, ":t") })
		else
			table.insert(shortened, { filename = file.filename })
		end
	end

	return shortened
end

function M.setup(opts)
	function _G.tabline()
		local tabs = shorten_filenames(require("recon").get_mark_config().marks)
		local tabline = ""

		local index = require("recon.mark").get_index_of(vim.fn.bufname())
		tabline = "%#ReconTabline# %#ReconTablineAnti#   %#ReconTabline#%*%T"

		for i, tab in ipairs(tabs) do
			local is_current = i == index

			local label

			if tab.filename == "" or tab.filename == "(empty)" then
				label = "(empty)"
				is_current = false
			else
				label = tab.filename
			end

			if is_current then
				tabline = tabline
					.. "%#ReconPrefix#"
					.. (opts.tabline_prefix or " %#ReconNumberActive#")
					.. i
					.. " %*%#ReconNumberActiveAnti# %*%#ReconActive#"
			else
				tabline = tabline
					.. "%#ReconPrefix#"
					.. (opts.tabline_prefix or " %#ReconNumberInactive#")
					.. i
					.. " %*%#ReconNumberInactiveAnti# %*%#ReconInactive#"
			end

			tabline = tabline .. label .. (opts.tabline_suffix or "  ") .. "%*"

			if i < #tabs then
				tabline = tabline .. "%T"
			end
		end

		return tabline
	end

	vim.opt.showtabline = 2

	vim.o.tabline = "%!v:lua.tabline()"

	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("recon", { clear = true }),
		pattern = { "*" },
		callback = function()
			local color = get_color("ReconActive", "bg#")

			if color == "" or color == nil then
				vim.api.nvim_set_hl(0, "ReconPrefix", {})
				vim.api.nvim_set_hl(0, "ReconActive", { link = "TablineSel" })
				vim.api.nvim_set_hl(0, "ReconNumberActive", { link = "TablineSel" })
				vim.api.nvim_set_hl(0, "ReconNumberActiveAnti", { link = "TablineSel" })
				vim.api.nvim_set_hl(0, "ReconInactivePrefix", { link = "Tabline" })
				vim.api.nvim_set_hl(0, "ReconInactive", { link = "Tabline" })
				vim.api.nvim_set_hl(0, "ReconNumberInactive", { link = "Tabline" })
				vim.api.nvim_set_hl(0, "ReconNumberInactiveAnti", { link = "Tabline" })
				vim.api.nvim_set_hl(0, "ReconTabline", { link = "Tabline" })
				vim.api.nvim_set_hl(0, "ReconTablineAnti", { link = "Tabline" })
				vim.api.nvim_set_hl(0, "ReconIconAnti", { link = "Tabline" })
				vim.api.nvim_set_hl(0, "ReconIcon", { link = "Tabline" })
			end
		end,
	})
end

return M
