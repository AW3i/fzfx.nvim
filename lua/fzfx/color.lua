-- Zero Dependency

-- local log = require("fzfx.log")

--- @param code string
--- @param fg boolean
--- @return string|nil
local function csi(code, fg)
    local control = fg and 38 or 48
    local r, g, b = code:match("#(..)(..)(..)")
    if r and g and b then
        r = tonumber(r, 16)
        g = tonumber(g, 16)
        b = tonumber(b, 16)
        local result = string.format("%d;2;%d;%d;%d", control, r, g, b)
        -- log.debug(
        --     "|fzfx.color - csi| rgb, color:%s, fg:%s, result:%s",
        --     vim.inspect(color),
        --     vim.inspect(fg),
        --     vim.inspect(result)
        -- )
        return result
    else
        local result = string.format("%d;5;%s", control, code)
        -- log.debug(
        --     "|fzfx.color - csi| non-rgb, color:%s, fg:%s, result:%s",
        --     vim.inspect(color),
        --     vim.inspect(fg),
        --     vim.inspect(result)
        -- )
        return result
    end
end

-- css color: https://www.quackit.com/css/css_color_codes.cfm
--- @type table<string, string>
local AnsiCode = {
    black = "0;30",
    ---@diagnostic disable-next-line: assign-type-mismatch
    grey = csi("#808080", true),
    ---@diagnostic disable-next-line: assign-type-mismatch
    silver = csi("#c0c0c0", true),
    ---@diagnostic disable-next-line: assign-type-mismatch
    white = csi("#ffffff", true),
    red = "0;31",
    magenta = "0;35",
    ---@diagnostic disable-next-line: assign-type-mismatch
    fuchsia = csi("#FF00FF", true),
    ---@diagnostic disable-next-line: assign-type-mismatch
    purple = csi("#800080", true),
    yellow = "0;33",
    ---@diagnostic disable-next-line: assign-type-mismatch
    orange = csi("#FFA500", true),
    ---@diagnostic disable-next-line: assign-type-mismatch
    olive = csi("#808000", true),
    green = "0;32",
    ---@diagnostic disable-next-line: assign-type-mismatch
    lime = csi("#00FF00", true),
    ---@diagnostic disable-next-line: assign-type-mismatch
    teal = csi("#008080", true),
    cyan = "0;36",
    ---@diagnostic disable-next-line: assign-type-mismatch
    aqua = csi("#00FFFF", true),
    blue = "0;34",
    ---@diagnostic disable-next-line: assign-type-mismatch
    navy = csi("#000080", true),
}

--- @param attr "fg"|"bg"
--- @param group string?
--- @return string? rbg code (#808080) or ansi code (354)
local function hlcode(attr, group)
    if type(group) ~= "string" then
        return nil
    end
    local gui = vim.fn.has("termguicolors") > 0 and vim.o.termguicolors
    local family = gui and "gui" or "cterm"
    local pattern = gui and "^#[%l%d]+" or "^[%d]+$"
    local code =
        vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(group)), attr, family)
    if string.find(code, pattern) then
        -- log.debug(
        --     "|fzfx.color - retrieve_vim_color| attr:%s, group:%s, code:%s",
        --     vim.inspect(attr),
        --     vim.inspect(group),
        --     vim.inspect(code)
        -- )
        return code
    end
    -- log.debug(
    --     "|fzfx.color - retrieve_vim_color| return nil, attr:%s, group:%s, code:%s",
    --     vim.inspect(attr),
    --     vim.inspect(group),
    --     vim.inspect(code)
    -- )
    return nil
end

--- @param text string
--- @param name string
--- @param hl string?
--- @return string
local function ansi(text, name, hl)
    local fgfmt = nil
    local fgcode = hlcode("fg", hl)
    if type(fgcode) == "string" then
        fgfmt = csi(fgcode, true)
        -- log.debug(
        --     "|fzfx.color - ansi| rgb, text:%s, name:%s, group:%s, fg:%s, fgcolor:%s",
        --     vim.inspect(text),
        --     vim.inspect(name),
        --     vim.inspect(hl),
        --     vim.inspect(fg),
        --     vim.inspect(fgcolor)
        -- )
    else
        fgfmt = AnsiCode[name]
        -- log.debug(
        --     "|fzfx.color - ansi| ansi, text:%s, name:%s, group:%s, fg:%s, fgcolor:%s",
        --     vim.inspect(text),
        --     vim.inspect(name),
        --     vim.inspect(hl),
        --     vim.inspect(fg),
        --     vim.inspect(fgcolor)
        -- )
    end

    local fmt = nil
    local bgcode = hlcode("bg", hl)
    if type(bgcode) == "string" then
        local bgcolor = csi(bgcode, false)
        -- log.debug(
        --     "|fzfx.color - ansi| rgb, text:%s, name:%s, group:%s, bg:%s, bgcolor:%s",
        --     vim.inspect(text),
        --     vim.inspect(name),
        --     vim.inspect(hl),
        --     vim.inspect(bg),
        --     vim.inspect(bgcolor)
        -- )
        fmt = string.format("%s;%s", fgfmt, bgcolor)
    else
        -- log.debug(
        --     "|fzfx.color - ansi| ansi, text:%s, name:%s, group:%s, bg:%s",
        --     vim.inspect(text),
        --     vim.inspect(name),
        --     vim.inspect(hl),
        --     vim.inspect(bg)
        -- )
        fmt = fgfmt
    end

    -- log.debug(
    --     "|fzfx.color - ansi| ansi, finalcolor:%s",
    --     vim.inspect(text),
    --     vim.inspect(name),
    --     vim.inspect(hl),
    --     vim.inspect(bg)
    -- )
    return string.format("[%sm%s[0m", fmt, text)
end

--- @param s string?
--- @return string?, integer?
local function erase(s)
    if type(s) ~= "string" then
        return s, nil
    end
    return s:gsub("\x1b%[%d+m\x1b%[K", "")
        :gsub("\x1b%[m\x1b%[K", "")
        :gsub("\x1b%[%d+;%d+;%d+;%d+;%d+m", "")
        :gsub("\x1b%[%d+;%d+;%d+;%d+m", "")
        :gsub("\x1b%[%d+;%d+;%d+m", "")
        :gsub("\x1b%[%d+;%d+m", "")
        :gsub("\x1b%[%d+m", "")
end

--- @type table<string, function>
local M = {
    hlcode = hlcode,
    csi = csi,
    ansi = ansi,
    erase = erase,
}

for name, code in pairs(AnsiCode) do
    --- @param text string
    --- @param hl string?
    --- @return string
    M[name] = function(text, hl)
        return ansi(text, name, hl)
    end
end

-- for color, default_hl in pairs({
--     black = "Comment",
--     red = "Exception",
--     green = "Label",
--     yellow = "LineNr",
--     blue = "TabLine",
--     magenta = "Special",
--     cyan = "String",
-- }) do
--     --- @param text string
--     --- @param hl string|nil
--     --- @return string
--     M[color] = function(text, hl)
--         return ansi(text, color, hl or default_hl)
--     end
--     M["ansi_" .. color] = function(text)
--         return ansi(text, color, nil)
--     end
-- end

--- @param fmt string
--- @param renderer fun(text:string,hl:string?):string
--- @param hl string?
--- @return string
M.render = function(renderer, hl, fmt, ...)
    local args = {}
    for _, a in ipairs({ ... }) do
        table.insert(args, renderer(a, hl))
    end
    ---@diagnostic disable-next-line: deprecated
    return string.format(fmt, unpack(args))
end

--- @param action string
--- @return string
M.unrestricted_mode_header = function(action)
    return M.render(
        M.magenta,
        "Special",
        ":: Press %s to unrestricted mode",
        string.upper(action)
    )
end

--- @param action string
--- @return string
M.restricted_mode_header = function(action)
    return M.render(
        M.magenta,
        "Special",
        ":: Press %s to restricted mode",
        string.upper(action)
    )
end

return M
