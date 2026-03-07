if vim.g.loaded_pulse then
	return
end
vim.g.loaded_pulse = true

-- Arrancamos con una tabla vacía (el init.lua pondrá los defaults)
require("pulse").setup({})
