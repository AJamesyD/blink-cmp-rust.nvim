local classify = require("blink-cmp-rust.classify")

local M = {}

---@class blink-cmp-rust.Config
---@field inherent_first boolean?
---@field inscope_first boolean?
---@field deprioritize_postfix boolean?
---@field deprioritize_common_traits boolean?
---@field deprioritize_deref boolean?
---@field deprioritize_borrow boolean?
---@field deprioritize_underscore boolean?
---@field extra_common_traits string[]?
---@field filter_imports string[]?

local DEFAULT_CONFIG = {
	inherent_first = true,
	inscope_first = true,
	deprioritize_postfix = true,
	deprioritize_common_traits = true,
	deprioritize_deref = true,
	deprioritize_borrow = true,
	deprioritize_underscore = true,
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

---@param _ctx table
---@param items table[]
---@return table[]
function M.transform_items(_ctx, items)
	if not enabled or vim.bo.filetype ~= "rust" then
		return items
	end

	local has_filters = #config.filter_imports > 0
	if not has_filters then
		for _, item in ipairs(items) do
			item._rust = classify.item(item, extra_traits)
		end
		return items
	end

	local filtered = {}
	for _, item in ipairs(items) do
		if not M._should_filter(item) then
			item._rust = classify.item(item, extra_traits)
			filtered[#filtered + 1] = item
		end
	end
	return filtered
end

---@param item table
---@return boolean
---@private
function M._should_filter(item)
	if not (item.data and item.data.imports) then
		return false
	end
	for _, entry in ipairs(item.data.imports) do
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

---@param a table
---@param b table
---@return boolean|nil
function M.compare(a, b)
	if not enabled then
		return nil
	end
	return classify.compare(a, b, config)
end

return M
