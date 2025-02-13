local cwd = vim.fn.getcwd()

describe("log", function()
    local assert_eq = assert.are.equal
    local assert_neq = assert.are_not.equal
    local assert_true = assert.is_true
    local assert_false = assert.is_false
    local assert_truthy = assert.is.truthy
    local assert_falsy = assert.is.falsy

    before_each(function()
        vim.api.nvim_command("cd " .. cwd)
    end)

    local log = require("fzfx.log")
    local LogLevel = require("fzfx.log").LogLevel
    log.setup({
        level = "DEBUG",
        console_log = false,
        file_log = true,
    })
    describe("[log]", function()
        it("echo", function()
            log.echo(LogLevel.INFO, "echo without parameters")
            log.echo(LogLevel.INFO, "echo with 1 parameters: %s", "a")
            log.echo(LogLevel.INFO, "echo with 2 parameters: %s, %d", "a", 1)
            log.echo(
                LogLevel.INFO,
                "echo with 3 parameters: %s, %d, %f",
                "a",
                1,
                3.12
            )
        end)
        it("debug", function()
            log.debug("debug without parameters")
            log.debug("debug with 1 parameters: %s", "a")
            log.debug("debug with 2 parameters: %s, %d", "a", 1)
            log.debug("debug with 3 parameters: %s, %d, %f", "a", 1, 3.12)
        end)
        it("info", function()
            log.info("info without parameters")
            log.info("info with 1 parameters: %s", "a")
            log.info("info with 2 parameters: %s, %d", "a", 1)
            log.info("info with 3 parameters: %s, %d, %f", "a", 1, 3.12)
        end)
        it("warn", function()
            log.warn("warn without parameters")
            log.warn("warn with 1 parameters: %s", "a")
            log.warn("warn with 2 parameters: %s, %d", "a", 1)
            log.warn("warn with 3 parameters: %s, %d, %f", "a", 1, 3.12)
        end)
        it("err", function()
            log.err("err without parameters")
            log.err("err with 1 parameters: %s", "a")
            log.err("err with 2 parameters: %s, %d", "a", 1)
            log.err("err with 3 parameters: %s, %d, %f", "a", 1, 3.12)
        end)
    end)
end)
