-- Classification and comparison for Rust completion items.
--
-- Two things to keep in mind when changing this file:
--
-- Lua's table.sort is unstable. Returning nil from compare for two items
-- doesn't preserve their original order — it reshuffles them. If RA already
-- gets something right (e.g. fields above methods via sortText), encode it
-- explicitly in the compare chain. The fields_first regression came from
-- assuming nil-fallthrough would preserve RA's ordering. It doesn't.
--
-- False positives are worse than false negatives. Promoting the wrong item
-- is more disruptive than failing to demote a noisy one. Use exact trait
-- name matches (== "Deref") not substrings, require the leading space in
-- the trait pattern, and check data.imports structure not just presence.

local M = {}

-- Matches rust-analyzer's "(as TraitName)" format
local TRAIT_PATTERN = " %(as (.-)%)"

-- Deref/DerefMut and Borrow/BorrowMut are excluded; they have dedicated flags
local COMMON_TRAITS = {
	Clone = true,
	Copy = true,
	Drop = true,
	ToString = true,
	ToOwned = true,
	PartialEq = true,
	PartialOrd = true,
	AsRef = true,
	AsMut = true,
	From = true,
	Into = true,
	TryFrom = true,
	TryInto = true,
	Default = true,
	Ord = true,
	Hash = true,
}

local DEREF_SET = {
	Deref = true,
	DerefMut = true,
}

local BORROW_SET = {
	Borrow = true,
	BorrowMut = true,
}

-- NOTE: LSP CompletionItemKind.Field (LSP spec §3.17, value 5).
-- RA uses this for struct fields in dot-completion.
local FIELD_KIND = 5

-- NOTE: LSP CompletionItemKind.Snippet (LSP spec §3.17, value 15).
-- RA uses this for postfix completions (.if, .match, .let).
-- Non-postfix RA snippets (pd, ppd) also get this kind but are rare and fine to deprioritize.
local SNIPPET_KIND = 15

-- NOTE: LSP CompletionItemKind.Text (LSP spec §3.17, value 1).
local TEXT_KIND = 1

-- NOTE: LSP CompletionItemKind.Keyword (LSP spec §3.17, value 14).
local KEYWORD_KIND = 14

---@class blink-cmp-rust.Classification
---@field is_field boolean
---@field is_inherent boolean
---@field needs_import boolean
---@field trait_name string?
---@field is_postfix boolean
---@field is_common_trait boolean
---@field is_deref boolean
---@field is_borrow boolean
---@field is_underscore boolean
---@field is_keyword boolean
---@field is_text boolean

---@class blink-cmp-rust.CompareConfig
---@field inscope_first boolean?
---@field deprioritize_underscore boolean?
---@field fields_first boolean?
---@field inherent_first boolean?
---@field deprioritize_postfix boolean?
---@field deprioritize_deref boolean?
---@field deprioritize_borrow boolean?
---@field deprioritize_common_traits boolean?
---@field deprioritize_text boolean?
---@field deprioritize_keywords boolean?

---@param item table
---@param extra_traits table<string, boolean>?
---@return blink-cmp-rust.Classification
function M.item(item, extra_traits)
	local detail = item.labelDetails and item.labelDetails.detail
	local trait_name = detail and detail:match(TRAIT_PATTERN)
	local is_postfix = item.kind == SNIPPET_KIND
	local is_inherent = trait_name == nil and not is_postfix
	local needs_import = item.data and item.data.imports and #item.data.imports > 0
	local is_field = item.kind == FIELD_KIND
	local is_underscore = item.label and item.label:sub(1, 1) == "_" or false

	local is_common_trait = false
	if trait_name then
		is_common_trait = COMMON_TRAITS[trait_name] or (extra_traits and extra_traits[trait_name]) or false
	end

	return {
		is_field = is_field,
		is_inherent = is_inherent,
		needs_import = needs_import or false,
		trait_name = trait_name,
		is_postfix = is_postfix,
		is_common_trait = is_common_trait,
		is_deref = trait_name and DEREF_SET[trait_name] or false,
		is_borrow = trait_name and BORROW_SET[trait_name] or false,
		is_underscore = is_underscore,
		is_keyword = item.kind == KEYWORD_KIND,
		is_text = item.kind == TEXT_KIND,
	}
end

---@param a table
---@param b table
---@param cfg blink-cmp-rust.CompareConfig
---@return boolean|nil
function M.compare(a, b, cfg)
	if not a._rust or not b._rust then
		return nil
	end

	local ar, br = a._rust, b._rust

	if cfg.inscope_first and ar.needs_import ~= br.needs_import then
		return br.needs_import
	end

	if cfg.deprioritize_underscore and ar.is_underscore ~= br.is_underscore then
		return br.is_underscore
	end

	if cfg.fields_first and ar.is_field ~= br.is_field then
		return ar.is_field
	end

	if cfg.inherent_first and ar.is_inherent ~= br.is_inherent then
		return ar.is_inherent
	end

	if cfg.deprioritize_postfix and ar.is_postfix ~= br.is_postfix then
		return br.is_postfix
	end

	if cfg.deprioritize_common_traits and ar.is_common_trait ~= br.is_common_trait then
		return br.is_common_trait
	end

	if cfg.deprioritize_borrow and ar.is_borrow ~= br.is_borrow then
		return br.is_borrow
	end

	if cfg.deprioritize_deref and ar.is_deref ~= br.is_deref then
		return br.is_deref
	end

	if cfg.deprioritize_text and ar.is_text ~= br.is_text then
		return br.is_text
	end

	if cfg.deprioritize_keywords and ar.is_keyword ~= br.is_keyword then
		return br.is_keyword
	end

	return nil
end

return M
