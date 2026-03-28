local M = {}
local state = require("pulse.state")

local function reset_idle_timer(workspace, idle_time)
    if not state.pulse_idle_timer or state.pulse_idle_timer:is_closing() then
        return
    end
    if not state.job_id or state.job_id <= 0 then
        return
    end

    state.pulse_idle_timer:stop()

    if state.currentStatus ~= "online" and state.currentStatus ~= "busy" then
        vim.fn.chansend(state.job_id, string.format('{ "status": "online", "file": "%s"}\n', workspace))
        state.currentStatus = "online"
    end

    state.pulse_idle_timer:start(
        idle_time,
        0,
        vim.schedule_wrap(function()
            if state.currentStatus ~= "idle" and state.currentStatus ~= "busy" then
                vim.fn.chansend(state.job_id, '{ "status": "idle", "file": ""}\n')
                state.currentStatus = "idle"
            end
        end)
    )
end

function M.setup(workspace, idle_time)
    reset_idle_timer(workspace, idle_time)

    vim.api.nvim_create_autocmd({ "TextChanged", "CursorMoved", "CursorMovedI" }, {
        callback = function()
            vim.schedule(function()
                reset_idle_timer(workspace, idle_time)
            end)
        end,
    })

    vim.keymap.set("n", "<leader>Cy", function()
        if state.job_id and state.job_id > 0 then
            vim.fn.chansend(state.job_id, '{ "status": "idle", "file": ""}\n')
            state.currentStatus = "idle"
        end
    end, { desc = "󰒲 Set status to idle" })

    vim.keymap.set("n", "<leader>Cb", function()
        if state.job_id and state.job_id > 0 then
            vim.fn.chansend(state.job_id, '{ "status": "busy", "file": ""}\n')
            state.currentStatus = "busy"
        end
    end, { desc = "󰗖 Set status to busy" })

    vim.keymap.set("n", "<leader>Co", function()
        if state.job_id and state.job_id > 0 then
            vim.fn.chansend(state.job_id, string.format('{ "status": "online", "file": "%s"}\n', workspace))
            state.currentStatus = "online"
        end
    end, {
        desc = "󰄬 Set status to online",
    })

    vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
            if state.job_id and state.job_id > 0 then
                vim.fn.chansend(state.job_id, '{ "status": "offline", "file": ""}\n')
            end
        end,
    })
end

return M
