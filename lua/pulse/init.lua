local M = {}
function M.setup(opts)
    opts = opts or {}
    local bin = require("pulse.binary").ensure_binary()
    local state = require("pulse.state")
    local commands = require("pulse.commands")

    if not bin or vim.fn.executable(bin) == 0 then
        vim.notify("Pulse: Binary not found or download failed", vim.log.levels.ERROR)
        return
    end
    local server_url = opts.server_url or ""
    local idle_time = opts.idle_time or 30000
    local validate = opts.validate or ""
    local isLocalhost = opts.isLocalhost or false

    local cmd = { bin, server_url, validate, isLocalhost }
    local path = vim.fn.getcwd()
    local workspace = vim.fn.fnamemodify(path, ":t")

    if state.job_id then
        vim.fn.jobstop(state.job_id)
    end

    if state.pulse_idle_timer then
        state.pulse_idle_timer:stop()
    end

    state.job_id = vim.fn.jobstart(cmd, {
        on_stderr = function(_, d, _)
            if d[1] ~= "" then
                vim.notify("Error:" .. d[1], vim.log.levels.ERROR)
            end
        end,
        on_stdout = function(_, d, _)
            vim.notify(d[1], vim.log.levels.INFO)
        end,
        on_exit = function(_, c, _)
            vim.notify("Process closed with code: " .. c, vim.log.levels.WARN)
        end,
    })
    if state.pulse_idle_timer then
        if not state.pulse_idle_timer:is_closing() then
            state.pulse_idle_timer:stop()
            state.pulse_idle_timer:close()
        end
    end
    local uv = vim.uv or vim.loop
state.pulse_idle_timer = uv.new_timer()
state.pulse_timer = uv.new_timer()


    state.pulse_timer:start(
        20000,
        20000,
        vim.schedule_wrap(function()
            if state.job_id then
                vim.fn.chansend(state.job_id, '{ "status": "", "file": ""}\n')
            end
        end)
    )

    vim.fn.chansend(state.job_id, string.format('{ "status": "online", "file": "%s"}\n', workspace))
    state.currentStatus = "online"

    if not state.pulse_idle_timer then
        return
    end
    commands.setup(workspace, opts.idle_time or 30000)
end

return M
