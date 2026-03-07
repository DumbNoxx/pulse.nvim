local M = {}

function M.ensure_binary()
	local info = debug.getinfo(1, "S").source
	if info:sub(1, 1) ~= "@" then
		return nil
	end
	local current_file = info:sub(2)

	local plugin_root = vim.fn.fnamemodify(current_file, ":p:h:h:h")

	local bin_dir = plugin_root .. "/bin"
	local bin_path = bin_dir .. "/pulse"

	if vim.fn.executable(bin_path) == 1 then
		return bin_path
	end
	vim.fn.mkdir(bin_dir, "p")
	local uname = vim.uv.os_uname()
	local os = uname.sysname:lower()
	local arch = uname.machine

	local arch_map = { x86_64 = "amd64", aarch64 = "arm64" }
	arch = arch_map[arch] or arch

	local binary_name = string.format("pulse.nvim_%s_%s", os, arch)
	local url = string.format("https://github.com/DumbNoxx/pulse.nvim/releases/latest/download/%s.tar.gz", binary_name)

	local download_cmd = string.format("curl -sL --fail %s | tar -xzf - -C %s", url, bin_dir)
	local output = vim.fn.system({ "sh", "-c", download_cmd })

	if vim.v.shell_error ~= 0 then
		vim.notify("Download error: " .. output, vim.log.levels.ERROR)
		return nil
	end
	if os ~= "windows_nt" then
		vim.fn.system("chmod +x " .. bin_path)
	end

	return bin_path
end

return M
