local log = require("fzfx.log")

--- @type boolean
local is_windows = vim.fn.has("win32") > 0 or vim.fn.has("win64") > 0
--- @type boolean
local is_macos = vim.fn.has("mac") > 0
--- @type string
local plugin_home = vim.fn["fzfx#nvim#plugin_home_dir"]()
--- @type string
local plugin_bin = is_windows and plugin_home .. "\\bin"
    or plugin_home .. "/bin"

--- @param path string
--- @return string
local function normalize_path(path)
    local result = path
    if string.match(path, "\\") then
        result, _ = string.gsub(path, "\\", "/")
    end
    return vim.fn.trim(result)
end

--- @alias VimScriptId string
--- @alias VimScriptPath string
--- @alias VimScriptIdInfoKey "script_id"|"script_path"
--- @alias VimScriptIdInfoValue VimScriptId|VimScriptPath
--- @alias VimScriptIdInfo table<VimScriptIdInfoKey, VimScriptIdInfoValue>
--- @param script_name string
--- @return VimScriptIdInfo
local function get_sinfo(script_name)
    local all_scripts = vim.fn.split(vim.fn.execute("scriptnames"), "\n")
    log.debug(
        "|fzfx.infra - get_sinfo| all_scripts:%s",
        vim.inspect(all_scripts)
    )
    local matched_line = nil
    for _, line in ipairs(all_scripts) do
        local normalized = normalize_path(line)
        if string.find(string.lower(normalized), string.lower(script_name)) then
            if matched_line == nil then
                matched_line = normalized
                break
            end
        end
    end

    if matched_line == nil then
        return { script_id = nil, script_path = nil }
    end

    local split_matched = vim.fn.split(matched_line)
    if #split_matched ~= 2 then
        log.err(
            "|fzfx.infra - get_sinfo| cannot parse matched script path: %s!",
            matched_line
        )
        return { script_id = nil, script_path = nil }
    end

    local first_entry = split_matched[1]
    local script_id = string.gsub(first_entry, ":", "")
    local script_path = split_matched[2]
    log.debug(
        "|fzfx.infra - get_sinfo| script_id:%s, script_path:%s",
        vim.inspect(script_id),
        vim.inspect(script_path)
    )
    return { script_id = script_id, script_path = script_path }
end

--- @return VimScriptId|nil
local function get_fzf_autoload_sid()
    local fzf_autoload_path = "fzf.vim/autoload/fzf/vim.vim"
    local fzf_plugin_path = "fzf.vim/plugin/fzf.vim"

    -- first try autoload
    local autoload_sinfo1 = get_sinfo(fzf_autoload_path)
    log.debug(
        "|fzfx.infra - get_fzf_autoload_sid| autoload_sinfo1:%s",
        vim.inspect(autoload_sinfo1)
    )
    if autoload_sinfo1.script_id ~= nil then
        return autoload_sinfo1.script_id
    end

    -- then try plugin
    local plugin_sinfo = get_sinfo(fzf_plugin_path)
    log.debug(
        "|fzfx.infra - get_fzf_autoload_sid| plugin_sinfo:%s",
        vim.inspect(plugin_sinfo)
    )
    if plugin_sinfo.script_id == nil then
        log.throw(
            "|fzfx.infra - get_fzf_autoload_sid| failed to find vimscript '%s'!",
            fzf_plugin_path
        )
        return nil
    end

    -- finally construct autoload by hand
    local plugin_path = plugin_sinfo.script_path
    local my_autoload_path = vim.fn.expand(
        string.sub(plugin_path, 1, #plugin_path - 15 + 1)
            .. "autoload/fzf/vim.vim"
    )
    log.debug(
        "|fzfx.infra - get_fzf_autoload_sid| fzf_plugin_path:%s, fzf_autoload_path:%s",
        plugin_path,
        my_autoload_path
    )

    if vim.fn.filereadable(my_autoload_path) > 0 then
        vim.cmd("source " .. my_autoload_path)
    else
        log.throw(
            "|fzfx.infra - get_fzf_autoload_sid| failed to load vimscript '%s'!",
            my_autoload_path
        )
        return nil
    end

    local autoload_sinfo2 = get_sinfo(fzf_autoload_path)
    log.debug(
        "|fzfx.infra - get_fzf_autoload_sid| fzf_plugin_path:%s, fzf_autoload_path:%s",
        plugin_path,
        my_autoload_path
    )
    if autoload_sinfo2.script_id == nil then
        log.throw(
            "|fzfx.infra - get_fzf_autoload_sid| failed to find vimscript '%s' again!",
            fzf_autoload_path
        )
        return nil
    end

    return autoload_sinfo2.script_id
end

--- @param sid VimScriptId
--- @param func_name string
--- @return string
local function get_func_snr(sid, func_name)
    return string.format("<SNR>%s_%s", sid, func_name)
end

local fzf_autoload_sid = get_fzf_autoload_sid()
log.debug("|fzfx.infra| fzf_autoload_sid:%s", fzf_autoload_sid)

local action_for = get_func_snr(fzf_autoload_sid --[[@as string]], "action_for")
local magenta = get_func_snr(fzf_autoload_sid --[[@as string]], "magenta")
local red = get_func_snr(fzf_autoload_sid --[[@as string]], "red")
local green = get_func_snr(fzf_autoload_sid --[[@as string]], "green")
local blue = get_func_snr(fzf_autoload_sid --[[@as string]], "blue")
local yellow = get_func_snr(fzf_autoload_sid --[[@as string]], "yellow")
local cyan = get_func_snr(fzf_autoload_sid --[[@as string]], "cyan")
local bufopen = get_func_snr(fzf_autoload_sid --[[@as string]], "bufopen")

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

    local lines = vim.fn.getlines(line_start, line_end)
    if #lines == 0 then
        return ""
    end

    if mode == "v" or mode == "\22" then
        local offset = string.lower(vim.o.selection) == "inclusive" and 1 or 2
        local last_line = string.sub(lines[#lines], 1, column_end - offset + 1)
        local first_line = string.sub(lines[1], column_start)
        log.debug(
            "|fzfx.infra - get_visual_lines| last_line:[%s], first_line:[%s]",
            last_line,
            first_line
        )
        lines[#lines] = last_line
        lines[1] = first_line
    elseif mode == "V" then
        if #lines == 1 then
            lines[1] = vim.fn.trim(lines[1])
        end
    end

    return table.concat(lines, "\n")
end

--- @return string
local function visual_selected()
    vim.cmd([[ execute "normal! \<ESC>" ]])
    local mode = vim.fn.visualmode()
    if mode == "v" or mode == "V" or mode == "\22" then
        return get_visual_lines(mode)
    end
    return ""
end

local M = {
    os = {
        is_windows = is_windows,
        is_macos = is_macos,
    },
    fs = {
        plugin_home = plugin_home,
        plugin_bin = plugin_bin,
    },
    func_snr = {
        magenta,
        red,
        green,
        blue,
        yellow,
        cyan,
        action_for,
        bufopen,
    },
    visual_selected = visual_selected,
}

log.debug("|fzfx.infra| %s", vim.inspect(M))

return M
