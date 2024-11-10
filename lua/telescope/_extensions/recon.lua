local utility = require("telescope.actions.utils")

local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
	error("This plugin requires nvim-telescope/telescope.nvim")
end

local select = function(selection)
	local file = selection[1]

	if selection.path then
		file = selection.path
	end

	pcall(require("recon.mark").add_file, file)
end
local mark_file = function(tb)
	if #require("telescope.actions.state").get_current_picker(tb):get_multi_selection() > 0 then
		utility.map_selections(tb, select)
	else
		utility.map_entries(tb, select)
	end

	require("telescope.actions").drop_all(tb)
	pcall(require("recon.ui").toggle_quick_menu)
end

return telescope.register_extension({
	setup = function(ext_config, config)
		telescope.setup({
			defaults = {
				mappings = {
					n = {
						["<C-h>"] = mark_file,
					},
					i = {
						["<C-h>"] = mark_file,
					},
				},
			},
		})
	end,
})
