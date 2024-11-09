local Path = require("plenary.path")
local Job = require("plenary.job")

local M = {}

function M.normalize_path(item)
	return Path:new(item):make_relative(M.project_key())
end

function M.project_key()
	return vim.loop.cwd()
end

function M.is_white_space(str)
	return str:gsub("%s", "") == ""
end

function M.os_cmd_run(cmd, cwd)
    if type(cmd) ~= "table" then
        print("Recon: [os_cmd_run]: cmd has to be a table")
        return {}
    end
    local command = table.remove(cmd, 1)
    local stderr = {}
    local stdout, ret = Job
        :new({
            command = command,
            args = cmd,
            cwd = cwd,
            on_stderr = function(_, data)
                table.insert(stderr, data)
            end,
        })
        :sync()
    return stdout, ret, stderr
end

function M.split_string(str, delimiter)
    local result = {}
    for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result
end

return M
