package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

-- Mock vim APIs before requiring the module
_G.vim = {
	tbl_deep_extend = function(_behavior, ...)
		local result = {}
		local function deep_merge(target, source)
			for k, v in pairs(source) do
				if type(v) == "table" and type(target[k]) == "table" then
					target[k] = deep_merge(target[k], v)
				else
					target[k] = v
				end
			end
			return target
		end

		local sources = { ... }
		for _, source in ipairs(sources) do
			if source then
				result = deep_merge(result, source)
			end
		end
		return result
	end,

	bo = { filetype = "rust" },

	startswith = function(str, prefix)
		return str:sub(1, #prefix) == prefix
	end,
}

local init

local function mock_item(opts)
	opts = opts or {}
	local item = {
		label = opts.label or "test_method",
		kind = opts.kind,
		client_name = opts.client_name,
	}

	if opts.imports then
		item.data = { imports = opts.imports }
	end

	return item
end

describe("init", function()
	before_each(function()
		package.loaded["blink-cmp-rust"] = nil
		init = require("blink-cmp-rust")
		init.setup()
		vim.bo.filetype = "rust"
	end)

	describe("setup", function()
		it("merges opts with defaults", function()
			init.setup({ inherent_first = false, extra_common_traits = { "MyTrait" } })

			local item = mock_item({ imports = { { full_import_path = "test::path" } } })
			init.transform_items({}, { item })

			assert.is_not_nil(item._rust)
		end)

		it("handles nil opts", function()
			assert.has_no.errors(function()
				init.setup(nil)
			end)
		end)

		it("resets state on multiple calls", function()
			init.setup({ extra_common_traits = { "FirstTrait" } })
			init.setup({ extra_common_traits = { "SecondTrait" } })

			local item = mock_item({ imports = { { full_import_path = "test::path" } } })
			init.transform_items({}, { item })

			assert.is_not_nil(item._rust)
		end)
	end)

	describe("transform_items", function()
		it("returns items unchanged for non-rust filetype", function()
			vim.bo.filetype = "javascript"
			local items = { mock_item() }
			local result = init.transform_items({}, items)

			assert.are.same(items, result)
			assert.is_nil(items[1]._rust)
		end)

		it("adds _rust classification when no filters configured", function()
			local items = { mock_item() }
			local result = init.transform_items({}, items)

			assert.are.same(items, result)
			assert.is_not_nil(items[1]._rust)
		end)

		it("filters items matching import prefixes", function()
			init.setup({ filter_imports = { "std::" } })
			local items = {
				mock_item({ imports = { { full_import_path = "std::collections::HashMap" } } }),
				mock_item({ imports = { { full_import_path = "my::module::Type" } } }),
			}

			local result = init.transform_items({}, items)

			assert.are.equal(1, #result)
			assert.are.equal("my::module::Type", result[1].data.imports[1].full_import_path)
		end)

		it("returns empty table when all items filtered", function()
			init.setup({ filter_imports = { "std::" } })
			local items = {
				mock_item({ imports = { { full_import_path = "std::vec::Vec" } } }),
			}

			local result = init.transform_items({}, items)

			assert.are.equal(0, #result)
		end)
	end)

	describe("_should_filter", function()
		before_each(function()
			init.setup({ filter_imports = { "std::", "tokio::" } })
		end)

		it("returns false when item has no data", function()
			local item = mock_item()
			assert.is_false(init._should_filter(item))
		end)

		it("returns false when item has no imports", function()
			local item = { data = {} }
			assert.is_false(init._should_filter(item))
		end)

		it("returns true when import matches prefix", function()
			local item = mock_item({ imports = { { full_import_path = "std::collections::HashMap" } } })
			assert.is_true(init._should_filter(item))
		end)

		it("returns false when import doesn't match any prefix", function()
			local item = mock_item({ imports = { { full_import_path = "my::module::Type" } } })
			assert.is_false(init._should_filter(item))
		end)

		it("returns true if any import matches", function()
			local item = mock_item({
				imports = {
					{ full_import_path = "my::module::Type" },
					{ full_import_path = "tokio::sync::Mutex" },
				},
			})
			assert.is_true(init._should_filter(item))
		end)

		it("handles imports without full_import_path", function()
			local item = mock_item({ imports = { {} } })
			assert.is_false(init._should_filter(item))
		end)
	end)

	describe("compare", function()
		it("delegates to classify.compare with current config", function()
			local a = { _rust = { needs_import = false } }
			local b = { _rust = { needs_import = true } }

			local result = init.compare(a, b)
			assert.is_true(result)
		end)

		it("returns nil for items without _rust metadata", function()
			local a = { label = "test" }
			local b = { label = "test" }

			assert.is_nil(init.compare(a, b))
		end)

		it("returns nil when disabled", function()
			init.enable(false)
			local a = { _rust = { needs_import = false } }
			local b = { _rust = { needs_import = true } }

			assert.is_nil(init.compare(a, b))
		end)
	end)

	describe("enabled toggle", function()
		it("is enabled by default", function()
			assert.is_true(init.is_enabled())
		end)

		it("toggle flips state and returns new value", function()
			assert.is_false(init.toggle())
			assert.is_false(init.is_enabled())
			assert.is_true(init.toggle())
			assert.is_true(init.is_enabled())
		end)

		it("enable sets explicit state", function()
			init.enable(false)
			assert.is_false(init.is_enabled())
			init.enable(true)
			assert.is_true(init.is_enabled())
		end)

		it("transform_items skips classification when disabled", function()
			init.enable(false)
			local items = { mock_item() }
			init.transform_items({}, items)

			assert.is_nil(items[1]._rust)
		end)
	end)

	describe("client_name filtering", function()
		it("classifies items from rust-analyzer (hyphenated)", function()
			local items = { mock_item({ client_name = "rust-analyzer" }) }
			init.transform_items({}, items)

			assert.is_not_nil(items[1]._rust)
		end)

		it("classifies items from rust_analyzer (underscored)", function()
			local items = { mock_item({ client_name = "rust_analyzer" }) }
			init.transform_items({}, items)

			assert.is_not_nil(items[1]._rust)
		end)

		it("classifies items with nil client_name (older blink.cmp)", function()
			local items = { mock_item({ client_name = nil }) }
			init.transform_items({}, items)

			assert.is_not_nil(items[1]._rust)
		end)

		it("skips items from non-RA servers", function()
			local items = { mock_item({ client_name = "typescript" }) }
			init.transform_items({}, items)

			assert.is_nil(items[1]._rust)
		end)
	end)
end)
