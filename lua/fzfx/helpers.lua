local log = require("fzfx.log")
local env = require("fzfx.env")
local path = require("fzfx.path")
local color = require("fzfx.color")
local conf = require("fzfx.config")
local yank_history = require("fzfx.yank_history")
local utils = require("fzfx.utils")

-- visual select {

--- @param mode string
--- @return string
local function get_visual_lines(mode)
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local line_start = start_pos[2]
    local column_start = start_pos[3]
    local line_end = end_pos[2]
    local column_end = end_pos[3]
    line_start = math.min(line_start, line_end)
    line_end = math.max(line_start, line_end)
    column_start = math.min(column_start, column_end)
    column_end = math.max(column_start, column_end)
    log.debug(
        "|fzfx.helpers - get_visual_lines| mode:%s, start_pos:%s, end_pos:%s",
        vim.inspect(mode),
        vim.inspect(start_pos),
        vim.inspect(end_pos)
    )
    log.debug(
        "|fzfx.helper - get_visual_lines| line_start:%s, line_end:%s, column_start:%s, column_end:%s",
        vim.inspect(line_start),
        vim.inspect(line_end),
        vim.inspect(column_start),
        vim.inspect(column_end)
    )

    local lines = vim.api.nvim_buf_get_lines(0, line_start - 1, line_end, false)
    if #lines == 0 then
        log.debug("|fzfx.helpers - get_visual_lines| empty lines")
        return ""
    end

    local cursor_pos = vim.fn.getpos(".")
    local cursor_line = cursor_pos[2]
    local cursor_column = cursor_pos[3]
    log.debug(
        "|fzfx.helpers - get_visual_lines| cursor_pos:%s, cursor_line:%s, cursor_column:%s",
        vim.inspect(cursor_pos),
        vim.inspect(cursor_line),
        vim.inspect(cursor_column)
    )
    if mode == "v" or mode == "\22" then
        local offset = string.lower(vim.o.selection) == "inclusive" and 1 or 2
        lines[#lines] = string.sub(lines[#lines], 1, column_end - offset + 1)
        lines[1] = string.sub(lines[1], column_start)
        log.debug(
            "|fzfx.helpers - get_visual_lines| v or \\22, lines:%s",
            vim.inspect(lines)
        )
    elseif mode == "V" then
        if #lines == 1 then
            lines[1] = vim.trim(lines[1])
        end
        log.debug(
            "|fzfx.helpers - get_visual_lines| V, lines:%s",
            vim.inspect(lines)
        )
    end
    return table.concat(lines, "\n")
end

--- @return string
local function visual_select()
    vim.cmd([[ execute "normal! \<ESC>" ]])
    local mode = vim.fn.visualmode()
    if mode == "v" or mode == "V" or mode == "\22" then
        return get_visual_lines(mode)
    end
    return ""
end

-- visual select }

--- @param opts Configs
--- @param feed_type "args"|"visual"|"cword"|"put"
--- @return string
local function get_command_feed(opts, feed_type)
    feed_type = string.lower(feed_type)
    if feed_type == "args" then
        return opts.args
    elseif feed_type == "visual" then
        return visual_select()
    elseif feed_type == "cword" then
        return vim.fn.expand("<cword>")
    elseif feed_type == "put" then
        local y = yank_history.get_yank()
        return (y ~= nil and type(y.regtext) == "string") and y.regtext or ""
    else
        log.throw(
            "|fzfx.helpers - get_command_feed| error! invalid command feed type! %s",
            vim.inspect(feed_type)
        )
        return ""
    end
end

-- fzf opts {

--- @return FzfOpt[]
local function generate_fzf_color_opts()
    if type(conf.get_config().fzf_color_opts) ~= "table" then
        return {}
    end
    local fzf_colors = conf.get_config().fzf_color_opts
    local builder = {}
    for name, opts in pairs(fzf_colors) do
        for i = 2, #opts do
            local c = color.hlcode(opts[1], opts[i])
            if type(c) == "string" and string.len(c) > 0 then
                table.insert(builder, string.format("%s:%s", name, c))
                break
            end
        end
    end
    log.debug(
        "|fzfx.helpers - make_fzf_color_opts| builder:%s",
        vim.inspect(builder)
    )
    return { { "--color", table.concat(builder, ",") } }
end

--- @return FzfOpt[]
local function generate_fzf_icon_opts()
    if type(conf.get_config().icons) ~= "table" then
        return {}
    end
    local icon_configs = conf.get_config().icons
    return {
        { "--pointer", icon_configs.fzf_pointer },
        { "--marker", icon_configs.fzf_marker },
    }
end

--- @param opts FzfOpt[]
--- @param o FzfOpt?
--- @return FzfOpt[]
local function append_fzf_opt(opts, o)
    if type(o) == "string" and string.len(o) > 0 then
        table.insert(opts, o)
    elseif type(o) == "table" and #o == 2 then
        local k = o[1]
        local v = o[2]
        table.insert(opts, string.format("%s %s", k, utils.shellescape(v)))
    else
        log.throw(
            "|fzfx.helpers - append_fzf_opt| invalid fzf opt: %s",
            vim.inspect(o)
        )
    end
    return opts
end

--- @param opts FzfOpt[]
--- @return FzfOpt[]
local function preprocess_fzf_opts(opts)
    if opts == nil or #opts == 0 then
        return {}
    end
    local result = {}
    for _, o in ipairs(opts) do
        if type(o) == "function" then
            local result_o = o()
            if result_o ~= nil then
                table.insert(result, result_o)
            end
        elseif o ~= nil then
            table.insert(result, o)
        end
    end
    return result
end

--- @param opts FzfOpt[]
--- @return string?
local function make_fzf_opts(opts)
    if opts == nil or #opts == 0 then
        return nil
    end
    local result = {}
    for _, o in ipairs(opts) do
        append_fzf_opt(result, o)
    end
    return table.concat(result, " ")
end

--- @return string?
local function make_fzf_default_opts()
    local opts = conf.get_config().fzf_opts
    local result = {}
    if type(opts) == "table" and #opts > 0 then
        for _, o in ipairs(opts) do
            append_fzf_opt(result, o)
        end
    end
    local color_opts = generate_fzf_color_opts()
    if type(color_opts) == "table" and #color_opts > 0 then
        for _, o in ipairs(color_opts) do
            append_fzf_opt(result, o)
        end
    end
    local icon_opts = generate_fzf_icon_opts()
    if type(icon_opts) == "table" and #icon_opts > 0 then
        for _, o in ipairs(icon_opts) do
            append_fzf_opt(result, o)
        end
    end
    return table.concat(result, " ")
end

-- fzf opts }

--- @return string|nil
local function nvim_exec()
    local exe_list = {}
    table.insert(exe_list, conf.get_config().env.nvim)
    table.insert(exe_list, vim.v.argv[1])
    table.insert(exe_list, vim.env.VIM)
    table.insert(exe_list, "nvim")
    for _, e in ipairs(exe_list) do
        if e ~= nil and vim.fn.executable(e) > 0 then
            return e
        end
    end
    log.throw("error! failed to found executable 'nvim' on path!")
    return nil
end

--- @return string|nil
local function fzf_exec()
    local exe_list = {}
    table.insert(exe_list, conf.get_config().env.fzf)
    table.insert(exe_list, vim.fn["fzf#exec"]())
    table.insert(exe_list, "fzf")
    for _, e in ipairs(exe_list) do
        if e ~= nil and vim.fn.executable(e) > 0 then
            return e
        end
    end
    log.throw("error! failed to found executable 'fzf' on path!")
    return nil
end

--- @return string
local function make_lua_command(...)
    local nvim_path = nvim_exec()
    local lua_path = path.join(path.base_dir(), "bin", ...)
    -- log.debug(
    --     "|fzfx.helpers - make_lua_command| lua_path:%s",
    --     vim.inspect(lua_path)
    -- )
    return string.format("%s -n --clean --headless -l %s", nvim_path, lua_path)
end

-- provider switch {

--- @class Switch
--- @field name string|nil
--- @field current string|nil
--- @field next string|nil
--- @field tempfile string|nil
local Switch = {
    name = nil,
    current = nil,
    next = nil,
    tempfile = nil,
}

--- @param name string
--- @param current string
--- @param next string
--- @return Switch
function Switch:new(name, current, next)
    local switch = vim.tbl_deep_extend("force", vim.deepcopy(Switch), {
        name = name,
        current = current,
        next = next,
        tempfile = env.debug_enable() and path.join(
            vim.fn.stdpath("data"),
            "fzfx.nvim",
            "switch_" .. name
        ) or vim.fn.tempname(),
    })
    vim.fn.writefile({ switch.current }, switch.tempfile, "b")
    log.debug("|fzfx.helpers - Switch:new| switch:%s", vim.inspect(switch))
    return switch
end

function Switch:switch()
    local tmp = self.next
    self.next = self.current
    self.current = tmp
    vim.fn.writefile({ self.current }, self.tempfile, "b")
end

-- provider switch }

local M = {
    get_command_feed = get_command_feed,
    preprocess_fzf_opts = preprocess_fzf_opts,
    make_fzf_opts = make_fzf_opts,
    make_fzf_default_opts = make_fzf_default_opts,
    nvim_exec = nvim_exec,
    fzf_exec = fzf_exec,
    make_lua_command = make_lua_command,
    Switch = Switch,
}

return M
