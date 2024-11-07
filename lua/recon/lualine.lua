local M = {}

M.sections = {
    lualine_a = {'filename'},
    lualine_b = {
        {
            "icon",
            fmt = function()
                if vim.fn.expand("%:t") == "Recon Marks" then
                   return " "
                else
                    return " "
                end
            end
        },
        {
            "cwd",
            fmt = function()
                return vim.fn.getcwd()
            end
        }
    }

}

M.filetypes = {
    'recon'
}

return M
