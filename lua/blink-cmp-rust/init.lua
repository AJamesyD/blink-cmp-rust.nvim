local classify = require("blink-cmp-rust.classify")

local M = {}

-- rustaceanvim uses "rust-analyzer", nvim-lspconfig uses "rust_analyzer"
local RA_NAMES = { ["rust-analyzer"] = true, ["rust_analyzer"] = true }

---@param item blink.cmp.CompletionItem
---@return boolean
local function is_rust_analyzer(item)
	-- nil client_name means blink.cmp didn't stamp it (older versions); classify anyway
	return item.client_name == nil or RA_NAMES[item.client_name] == true
end

---@class blink-cmp-rust.Config
---@field inscope_first boolean?
---@field deprioritize_underscore boolean?
---@field fields_first boolean?
---@field inherent_first boolean?
---@field deprioritize_postfix boolean?
---@field deprioritize_deref boolean?
---@field deprioritize_borrow boolean?
---@field deprioritize_common_traits boolean?
---@field deprioritize_keywords boolean?
---@field deprioritize_text boolean?
---@field extra_common_traits string[]?
---@field filter_imports string[]?

local DEFAULT_CONFIG = {
	inscope_first = true,
	deprioritize_underscore = true,
	fields_first = true,
	inherent_first = true,
	deprioritize_postfix = true,
	deprioritize_deref = true,
	deprioritize_borrow = true,
	deprioritize_common_traits = true,
	deprioritize_keywords = true,
	deprioritize_text = true,
	extra_common_traits = {},
	filter_imports = {},
}

local config = vim.tbl_deep_extend("force", DEFAULT_CONFIG, {})
local extra_traits = {}
local enabled = true

---@param opts blink-cmp-rust.Config?
function M.setup(opts)
	config = vim.tbl_deep_extend("force", DEFAULT_CONFIG, opts or {})
	extra_traits = {}
	for _, trait in ipairs(config.extra_common_traits or {}) do
		extra_traits[trait] = true
	end
end

---@return boolean
function M.toggle()
	enabled = not enabled
	return enabled
end

---@param state boolean
function M.enable(state)
	enabled = state
end

---@return boolean
function M.is_enabled()
	return enabled
end

---@param _ctx blink.cmp.Context
---@param items blink.cmp.CompletionItem[]
---@return blink.cmp.CompletionItem[]
function M.transform_items(_ctx, items) ---@diagnostic disable-line: unused-local
	if not enabled or vim.bo.filetype ~= "rust" then
		return items
	end

	local has_filters = #config.filter_imports > 0
	if not has_filters then
		for _, item in ipairs(items) do
			if is_rust_analyzer(item) then
				---@cast item blink-cmp-rust.CompletionItem
				item._rust = classify.item(item, extra_traits)
			end
		end
		return items
	end

	local filtered = {}
	for _, item in ipairs(items) do
		if not is_rust_analyzer(item) then
			filtered[#filtered + 1] = item
		elseif not M._should_filter(item) then
			---@cast item blink-cmp-rust.CompletionItem
			item._rust = classify.item(item, extra_traits)
			filtered[#filtered + 1] = item
		end
	end
	return filtered
end

---@param item blink.cmp.CompletionItem
---@return boolean
---@private
function M._should_filter(item)
	if not (item.data and item.data.imports) then ---@diagnostic disable-line: undefined-field
		return false
	end
	for _, entry in ipairs(item.data.imports) do ---@diagnostic disable-line: undefined-field
		if entry.full_import_path then
			for _, prefix in ipairs(config.filter_imports) do
				if vim.startswith(entry.full_import_path, prefix) then
					return true
				end
			end
		end
	end
	return false
end

---@param a blink-cmp-rust.CompletionItem
---@param b blink-cmp-rust.CompletionItem
---@return boolean|nil
function M.compare(a, b)
	if not enabled then
		return nil
	end
	return classify.compare(a, b, config)
end

return M
