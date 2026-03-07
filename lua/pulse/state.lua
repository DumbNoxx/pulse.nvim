local M = {
	currentStatus = "offline",
	job_id = nil,
	---@type uv.uv_timer_t|nil
	pulse_idle_timer = nil,
	---@type uv.uv_timer_t|nil
	pulse_timer = nil,
}

return M
