local M = {}

function M.setup(opts)
	opts = opts or {}
	local function ensure_binary()
		local plugin_path = vim.api.nvim_get_runtime_file("", false)[1]
		local bin_dir = plugin_path .. "/bin"
		local bin_path = bin_dir .. "/pulse"

		if vim.fn.executable(bin_path) == 1 then
			return bin_path
		end
		vim.fn.mkdir(bin_dir, "p")
		local uname = vim.uv.os_uname()
		local os = uname.sysname:lower()
		local arch = uname.machine

		if arch == "x86_64" then
			arch = "amd64"
		end
		if arch == "aarch64" then
			arch = "arm64"
		end

		local binary_name = string.format("pulse_%s_%s", os, arch)
		local url = string.format("https://github.com/DumbNoxx/puslse.nvim/releases/download/latest/%s", binary_name)

		local download_cmd = string.format("curl -L %s | tar -xz -C %s", url, bin_path)
		vim.fn.system(download_cmd)

		if os ~= "windows_nt" then
			vim.fn.system("chmod +x " .. bin_path)
		end

		return bin_path
	end

	local server_url = opts.server_url or ""
	local idle_time = opts.idle_time or 30000
	local validate = opts.validate or ""
	local isLocalhost = opts.isLocalhost or false

	local cmd = { ensure_binary(), server_url, validate, isLocalhost }
	local path = vim.fn.getcwd()
	local workspace = vim.fn.fnamemodify(path, ":t")
	local currentStatus = ""

	if _G.pulse_job_id then
		vim.fn.jobstop(_G.pulse_job_id)
	end

	if _G.pulse_idle_timer then
		_G.pulse_idle_timer:stop()
	end

	local test = vim.fn.jobstart(cmd, {
		on_stderr = function(_, d, _)
			if d[1] ~= "" then
				vim.notify("Error : " .. d[1], vim.log.levels.ERROR)
			end
		end,
		on_stdout = function(_, d, _)
			vim.notify(d[1], vim.log.levels.INFO)
		end,
		on_exit = function(_, c, _)
			vim.notify("Proccess close for code: " .. c, vim.log.levels.WARN)
		end,
	})

	if _G.pulse_timer then
		_G.pulse_timer:stop()
	end

	_G.pulse_job_id = test
	_G.pulse_idle_timer = vim.uv.new_timer()
	_G.pulse_timer = vim.loop.new_timer()
	_G.pulse_timer:start(
		20000,
		20000,
		vim.schedule_wrap(function()
			if _G.pulse_job_id then
				vim.fn.chansend(_G.pulse_job_id, '{ "status": "", "file": ""}\n')
			end
		end)
	)

	vim.fn.chansend(test, string.format('{ "status": "online", "file": "%s"}\n', workspace))
	currentStatus = "online"

	vim.api.nvim_create_autocmd({ "TextChanged", "CursorMoved", "CursorMovedI" }, {
		callback = function()
			vim.schedule(function()
				if not _G.pulse_idle_timer then
					return
				end
				_G.pulse_idle_timer:stop()

				if currentStatus ~= "online" and currentStatus ~= "busy" then
					vim.fn.chansend(test, string.format('{ "status": "online", "file": "%s"}\n', workspace))
					currentStatus = "online"
				end

				_G.pulse_idle_timer:start(
					idle_time,
					0,
					vim.schedule_wrap(function()
						if currentStatus ~= "idle" and currentStatus ~= "busy" then
							vim.fn.chansend(test, '{ "status": "idle", "file": ""}\n')
							currentStatus = "idle"
						end
					end)
				)
			end)
		end,
	})

	if not _G.pulse_idle_timer then
		return
	end

	_G.pulse_idle_timer:start(
		idle_time,
		0,
		vim.schedule_wrap(function()
			if currentStatus ~= "idle" and currentStatus ~= "busy" then
				vim.fn.chansend(test, '{ "status": "idle", "file": ""}\n')
				currentStatus = "idle"
			end
		end)
	)

	vim.keymap.set("n", "<leader>Ci", function()
		vim.fn.chansend(test, '{ "status": "idle", "file": ""}\n')
		currentStatus = "idle"
	end, { desc = "Poner tu estado idle" })

	vim.keymap.set("n", "<leader>Cb", function()
		vim.fn.chansend(test, '{ "status": "busy", "file": ""}\n')
		currentStatus = "busy"
	end, { desc = "Poner tu estado en ocupado" })

	vim.keymap.set("n", "<leader>Co", function()
		vim.fn.chansend(test, string.format('{ "status": "online", "file": "%s"}\n', workspace))
		currentStatus = "online"
	end, {
		desc = "Poner tu estado online",
	})
end

return M
