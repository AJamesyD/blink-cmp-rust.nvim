package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local classify = require("blink-cmp-rust.classify")

-- NOTE: must stay in sync with DEFAULT_CONFIG in init.lua
local DEFAULT_CFG = {
	inscope_first = true,
	deprioritize_underscore = true,
	fields_first = true,
	inherent_first = true,
	deprioritize_postfix = true,
	deprioritize_deref = true,
	deprioritize_borrow = true,
	deprioritize_common_traits = true,
}

-- Helper to create mock LSP completion items
local function mock_item(opts)
	opts = opts or {}
	local item = {
		label = opts.label or "test_method",
		kind = opts.kind,
	}

	if opts.detail then
		item.labelDetails = { detail = opts.detail }
	end

	if opts.imports then
		item.data = { imports = opts.imports }
	end

	return item
end

describe("classify.item", function()
	it("classifies inherent method (no trait pattern)", function()
		local item = mock_item({ label = "clone" })
		local result = classify.item(item)

		assert.is_true(result.is_inherent)
		assert.is_nil(result.trait_name)
		assert.is_false(result.is_common_trait)
		assert.is_false(result.needs_import)
	end)

	it("classifies trait method with common trait", function()
		local item = mock_item({ detail = " (as Clone)" })
		local result = classify.item(item)

		assert.is_false(result.is_inherent)
		assert.are.equal("Clone", result.trait_name)
		assert.is_true(result.is_common_trait)
	end)

	it("classifies Ord and Hash as common traits", function()
		local ord = classify.item(mock_item({ detail = " (as Ord)" }))
		local hash = classify.item(mock_item({ detail = " (as Hash)" }))

		assert.is_true(ord.is_common_trait)
		assert.is_true(hash.is_common_trait)
	end)

	it("classifies trait method with non-common trait", function()
		local item = mock_item({ detail = " (as MyTrait)" })
		local result = classify.item(item)

		assert.is_false(result.is_inherent)
		assert.are.equal("MyTrait", result.trait_name)
		assert.is_false(result.is_common_trait)
	end)

	it("identifies deref trait", function()
		local item = mock_item({ detail = " (as Deref)" })
		local result = classify.item(item)

		assert.is_true(result.is_deref)
		assert.is_false(result.is_borrow)
	end)

	it("identifies borrow trait", function()
		local item = mock_item({ detail = " (as Borrow)" })
		local result = classify.item(item)

		assert.is_true(result.is_borrow)
		assert.is_false(result.is_deref)
	end)

	it("identifies DerefMut trait", function()
		local item = mock_item({ detail = " (as DerefMut)" })
		local result = classify.item(item)

		assert.is_true(result.is_deref)
	end)

	it("identifies BorrowMut trait", function()
		local item = mock_item({ detail = " (as BorrowMut)" })
		local result = classify.item(item)

		assert.is_true(result.is_borrow)
	end)

	it("respects extra_traits parameter", function()
		local item = mock_item({ detail = " (as MyCustomTrait)" })
		local result = classify.item(item, { MyCustomTrait = true })

		assert.is_true(result.is_common_trait)
	end)

	it("does not treat unknown trait as common without extra_traits", function()
		local item = mock_item({ detail = " (as MyCustomTrait)" })
		local result = classify.item(item)

		assert.is_false(result.is_common_trait)
	end)

	it("does not treat deref/borrow as common traits (they have dedicated flags)", function()
		for _, trait in ipairs({ "Deref", "DerefMut", "Borrow", "BorrowMut" }) do
			local item = mock_item({ detail = " (as " .. trait .. ")" })
			local result = classify.item(item)
			assert.is_false(result.is_common_trait, trait .. " should not be a common trait")
		end
	end)

	it("handles nil detail without label fallback", function()
		local item = mock_item({ label = "clone" })
		local result = classify.item(item)

		assert.is_true(result.is_inherent)
		assert.is_nil(result.trait_name)
	end)

	it("identifies import needed", function()
		local item = mock_item({ imports = { { full_import_path = "std::collections::HashMap" } } })
		local result = classify.item(item)

		assert.is_true(result.needs_import)
	end)

	it("identifies postfix completion", function()
		local item = mock_item({ kind = 15 })
		local result = classify.item(item)

		assert.is_true(result.is_postfix)
	end)

	it("identifies underscore prefix", function()
		local item = mock_item({ label = "_private_method" })
		local result = classify.item(item)

		assert.is_true(result.is_underscore)
	end)

	it("handles missing labelDetails gracefully", function()
		local item = { label = "test_method" }
		local result = classify.item(item)

		assert.is_true(result.is_inherent)
		assert.is_false(result.needs_import)
	end)

	it("handles missing data gracefully", function()
		local item = mock_item({})
		local result = classify.item(item)

		assert.is_false(result.needs_import)
	end)
end)

describe("classify.compare", function()
	it("returns nil when items lack _rust metadata", function()
		local a = { label = "test" }
		local b = { label = "test", _rust = {} }

		assert.is_nil(classify.compare(a, b, DEFAULT_CFG))
		assert.is_nil(classify.compare(b, a, DEFAULT_CFG))
	end)

	it("prioritizes in-scope over import (inscope_first)", function()
		local inscope = { _rust = { needs_import = false } }
		local import = { _rust = { needs_import = true } }

		assert.is_true(classify.compare(inscope, import, DEFAULT_CFG))
		assert.is_false(classify.compare(import, inscope, DEFAULT_CFG))
	end)

	it("prioritizes inherent over trait (inherent_first)", function()
		local inherent = { _rust = { is_inherent = true, needs_import = false } }
		local trait = { _rust = { is_inherent = false, needs_import = false } }

		assert.is_true(classify.compare(inherent, trait, DEFAULT_CFG))
		assert.is_false(classify.compare(trait, inherent, DEFAULT_CFG))
	end)

	it("deprioritizes postfix", function()
		local normal = { _rust = { is_postfix = false, needs_import = false, is_inherent = true } }
		local postfix = { _rust = { is_postfix = true, needs_import = false, is_inherent = true } }

		assert.is_true(classify.compare(normal, postfix, DEFAULT_CFG))
		assert.is_false(classify.compare(postfix, normal, DEFAULT_CFG))
	end)

	it("deprioritizes deref traits", function()
		local normal = { _rust = { is_deref = false, needs_import = false, is_inherent = false, is_postfix = false } }
		local deref = { _rust = { is_deref = true, needs_import = false, is_inherent = false, is_postfix = false } }

		assert.is_true(classify.compare(normal, deref, DEFAULT_CFG))
		assert.is_false(classify.compare(deref, normal, DEFAULT_CFG))
	end)

	it("deprioritizes borrow traits", function()
		local normal = {
			_rust = {
				is_borrow = false,
				needs_import = false,
				is_inherent = false,
				is_postfix = false,
				is_deref = false,
			},
		}
		local borrow = {
			_rust = {
				is_borrow = true,
				needs_import = false,
				is_inherent = false,
				is_postfix = false,
				is_deref = false,
			},
		}

		assert.is_true(classify.compare(normal, borrow, DEFAULT_CFG))
		assert.is_false(classify.compare(borrow, normal, DEFAULT_CFG))
	end)

	it("deprioritizes common traits", function()
		local uncommon = {
			_rust = {
				is_common_trait = false,
				needs_import = false,
				is_inherent = false,
				is_postfix = false,
				is_deref = false,
				is_borrow = false,
			},
		}
		local common = {
			_rust = {
				is_common_trait = true,
				needs_import = false,
				is_inherent = false,
				is_postfix = false,
				is_deref = false,
				is_borrow = false,
			},
		}

		assert.is_true(classify.compare(uncommon, common, DEFAULT_CFG))
		assert.is_false(classify.compare(common, uncommon, DEFAULT_CFG))
	end)

	it("deprioritizes underscore methods", function()
		local normal = {
			_rust = {
				is_underscore = false,
				needs_import = false,
				is_inherent = false,
				is_postfix = false,
				is_deref = false,
				is_borrow = false,
				is_common_trait = false,
			},
		}
		local underscore = {
			_rust = {
				is_underscore = true,
				needs_import = false,
				is_inherent = false,
				is_postfix = false,
				is_deref = false,
				is_borrow = false,
				is_common_trait = false,
			},
		}

		assert.is_true(classify.compare(normal, underscore, DEFAULT_CFG))
		assert.is_false(classify.compare(underscore, normal, DEFAULT_CFG))
	end)

	it("returns nil when items are equal", function()
		local a = { _rust = { needs_import = false, is_inherent = true, is_postfix = false } }
		local b = { _rust = { needs_import = false, is_inherent = true, is_postfix = false } }

		assert.is_nil(classify.compare(a, b, DEFAULT_CFG))
	end)

	it("respects config toggles", function()
		local cfg = { inscope_first = false, inherent_first = false, deprioritize_postfix = false }
		local inscope = { _rust = { needs_import = false } }
		local import = { _rust = { needs_import = true } }

		assert.is_nil(classify.compare(inscope, import, cfg))
	end)

	it("follows priority chain: inscope beats inherent", function()
		local inscope_trait = { _rust = { needs_import = false, is_inherent = false } }
		local import_inherent = { _rust = { needs_import = true, is_inherent = true } }

		assert.is_true(classify.compare(inscope_trait, import_inherent, DEFAULT_CFG))
	end)

	it("follows priority chain: inherent beats postfix", function()
		local inherent_normal = { _rust = { needs_import = false, is_inherent = true, is_postfix = false } }
		local trait_postfix = { _rust = { needs_import = false, is_inherent = false, is_postfix = true } }

		assert.is_true(classify.compare(inherent_normal, trait_postfix, DEFAULT_CFG))
	end)

	it("handles full priority chain", function()
		local best = {
			_rust = {
				needs_import = false,
				is_inherent = true,
				is_postfix = false,
				is_deref = false,
				is_borrow = false,
				is_common_trait = false,
				is_underscore = false,
			},
		}
		local worst = {
			_rust = {
				needs_import = true,
				is_inherent = false,
				is_postfix = true,
				is_deref = true,
				is_borrow = true,
				is_common_trait = true,
				is_underscore = true,
			},
		}

		assert.is_true(classify.compare(best, worst, DEFAULT_CFG))
		assert.is_false(classify.compare(worst, best, DEFAULT_CFG))
	end)
end)

describe("config sync", function()
	it("DEFAULT_CFG covers all compare config fields", function()
		local expected_keys = {
			"inscope_first",
			"deprioritize_underscore",
			"fields_first",
			"inherent_first",
			"deprioritize_postfix",
			"deprioritize_deref",
			"deprioritize_borrow",
			"deprioritize_common_traits",
		}
		for _, key in ipairs(expected_keys) do
			assert.is_not_nil(DEFAULT_CFG[key], "DEFAULT_CFG missing key: " .. key)
		end
	end)
end)
