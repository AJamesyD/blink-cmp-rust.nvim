# blink-cmp-rust.nvim

[![CI](https://github.com/AJamesyD/blink-cmp-rust.nvim/actions/workflows/ci.yml/badge.svg?branch=mainline)](https://github.com/AJamesyD/blink-cmp-rust.nvim/actions/workflows/ci.yml)

Rust-aware completion sorting for [blink.cmp](https://github.com/Saghen/blink.cmp).

When you type `my_struct.` in Rust, `clone()`, `into()`, and other trait methods regularly appear above the methods you actually defined.
This plugin fixes that by sorting completions into categories that fuzzy score can't override.

## What changes

- **Your methods first.** Methods from `impl MyStruct` appear above trait methods like `clone()` or `eq()`.
- **Imported items first.** Completions already in scope appear above those that would trigger an auto-import.
- **Noise sinks to the bottom.** Common trait methods (`Clone`, `Copy`, `Default`, `From`, `Into`, ...),
  Deref/Borrow-forwarded methods, postfix completions, and underscore-prefixed items are pushed to the end.
- **Unwanted imports hidden.** Optionally filter out completions from specific import paths entirely.

Every feature is toggleable. Only activates in Rust files.

## Requirements

- [blink.cmp](https://github.com/Saghen/blink.cmp) v1.8.0+ (`fuzzy.sorts` function support)
- rust-analyzer LSP

## Installation

Add as a dependency to your blink.cmp spec:

```lua
{
  "saghen/blink.cmp",
  dependencies = {
    { "AJamesyD/blink-cmp-rust.nvim", opts = {} },
  },
  opts = function(_, opts)
    local ok, rust_cmp = pcall(require, "blink-cmp-rust")
    if not ok then return opts end

    opts.sources = vim.tbl_deep_extend("force", opts.sources or {}, {
      providers = {
        lsp = {
          transform_items = function(ctx, items)
            return rust_cmp.transform_items(ctx, items)
          end,
        },
      },
    })

    opts.fuzzy = vim.tbl_deep_extend("force", opts.fuzzy or {}, {
      sorts = function()
        if vim.bo.filetype == "rust" then
          return vim.list_extend({ rust_cmp.compare }, { "score", "sort_text" })
        end
        return { "score", "sort_text" }
      end,
    })

    return opts
  end,
}
```

<details>
<summary>Advanced: chaining with existing plugins and custom sorts</summary>

If you have other plugins that set `transform_items` or a custom `fuzzy.sorts`, use this
expanded snippet to compose with them instead of overwriting:

```lua
{
  "saghen/blink.cmp",
  dependencies = {
    { "AJamesyD/blink-cmp-rust.nvim", opts = {} },
  },
  opts = function(_, opts)
    -- pcall so blink.cmp still works if this plugin is removed
    local ok, rust_cmp = pcall(require, "blink-cmp-rust")
    if not ok then return opts end

    -- Chain with any existing transform_items (e.g. from another plugin)
    local existing_transform = opts.sources
      and opts.sources.providers
      and opts.sources.providers.lsp
      and opts.sources.providers.lsp.transform_items

    opts.sources = vim.tbl_deep_extend("force", opts.sources or {}, {
      providers = {
        lsp = {
          transform_items = function(ctx, items)
            if existing_transform then
              items = existing_transform(ctx, items)
            end
            return rust_cmp.transform_items(ctx, items)
          end,
        },
      },
    })

    -- Only apply Rust sorting in Rust files; other filetypes are unaffected
    local default_sorts = opts.fuzzy and opts.fuzzy.sorts
    opts.fuzzy = vim.tbl_deep_extend("force", opts.fuzzy or {}, {
      sorts = function()
        local base = type(default_sorts) == "function" and default_sorts()
          or default_sorts
          or { "score", "sort_text" }
        if vim.bo.filetype == "rust" then
          return vim.list_extend({ rust_cmp.compare }, base)
        end
        return base
      end,
    })

    return opts
  end,
}
```

</details>

## Configuration

All sorting features are enabled by default. Set any option to `false` to disable that sorting dimension. Items will be treated equally for that criterion and sorted by the remaining rules.

```lua
{
  "AJamesyD/blink-cmp-rust.nvim",
  opts = {
    -- Show methods from `impl MyStruct` above trait methods like clone() or eq().
    inherent_first = true,

    -- Show already-imported items above completions that would auto-import.
    inscope_first = true,

    -- Push postfix completions (.if, .match, .let) to the bottom.
    deprioritize_postfix = true,

    -- Push common trait methods to the bottom: Clone, Copy, Drop, Default,
    -- From, Into, TryFrom, TryInto, ToString, ToOwned, PartialEq, PartialOrd,
    -- AsRef, AsMut. Deref and Borrow have their own flags below.
    deprioritize_common_traits = true,

    -- Push methods available through Deref/DerefMut coercion below the
    -- type's own methods (e.g. str methods when completing on String).
    deprioritize_deref = true,

    -- Push methods from Borrow/BorrowMut below the type's own methods.
    deprioritize_borrow = true,

    -- Push _prefixed items (_private_field, _unused) to the bottom.
    deprioritize_underscore = true,

    -- Additional traits to treat as common and push to the bottom.
    -- Example: { "Debug", "Display", "Iterator" }
    extra_common_traits = {},

    -- Import paths to remove from completions entirely (not just deprioritized).
    -- Matches against the full import path.
    -- Example: { "tokio::runtime", "std::os" }
    filter_imports = {},
  },
}
```

## Runtime toggle

Disable the plugin at runtime to fall back to blink.cmp's default sorting.

```lua
-- flip on/off, returns new state
require("blink-cmp-rust").toggle()
-- explicitly enable/disable
require("blink-cmp-rust").enable(true)
require("blink-cmp-rust").enable(false)
-- query current state
require("blink-cmp-rust").is_enabled()
```

Simple keymap:

```lua
vim.keymap.set("n", "<leader>ur", function()
	require("blink-cmp-rust").toggle()
end, { desc = "Toggle Rust completion sorting" })
```

<details>
<summary>Advanced: snacks.nvim toggle integration</summary>

If you use [snacks.nvim](https://github.com/folke/snacks.nvim), you can register a proper toggle with notifications and which-key support:

```lua
require("snacks")
	.toggle({
		name = "Rust Completion Sorting",
		get = function()
			return require("blink-cmp-rust").is_enabled()
		end,
		set = function(state)
			require("blink-cmp-rust").enable(state)
		end,
	})
	:map("<leader>ur")
```

</details>

## How it works

The plugin hooks into blink.cmp's `transform_items` and `fuzzy.sorts` to classify and sort completion items.
Each item is tagged with metadata based on rust-analyzer's completion response,
then sorted by this priority (highest to lowest):

1. **In-scope**: items already imported
2. **Inherent**: methods defined directly on the type (`impl MyStruct`)
3. **Non-common trait**: trait methods not in the common/deref/borrow lists (implicit: anything not deprioritized)
4. **Deref-forwarded**: methods available through `Deref`/`DerefMut` coercion
5. **Borrow-forwarded**: methods from `Borrow`/`BorrowMut`
6. **Common trait**: `Clone`, `Copy`, `Default`, `From`, `Into`, etc.
7. **Underscore-prefixed**: `_private_field`, `_unused`
8. **Postfix**: `.if`, `.match`, `.let`

Within each tier, blink.cmp's normal fuzzy scoring applies.

## Troubleshooting

### Completions look the same after installing

- **Check your filetype.** Run `:set ft?` in a Rust buffer. It should print `filetype=rust`. The plugin does nothing in other filetypes.
- **Check your blink.cmp version.** This plugin requires v1.8.0+ for `fuzzy.sorts` function support. Older versions silently ignore the custom sort.
- **Check that setup ran.** With lazy.nvim, `opts = {}` in the dependency spec is enough. Other plugin managers may need an explicit `require("blink-cmp-rust").setup()` call.

### Verifying the plugin is active

`vim.print` inside completion callbacks is swallowed by blink.cmp's UI. Use file-based logging to inspect what the plugin sees:

```lua
-- Add temporarily inside the transform_items wrapper in your blink.cmp config:
vim.fn.writefile({ vim.inspect(items[1]) }, "/tmp/blink-rust-diag.log", "a")
```

If items have a `_rust` field in the output, the plugin is classifying them correctly.

## Credits

Thanks to [zjp-CN](https://github.com/zjp-CN) for [nvim-cmp-lsp-rs](https://github.com/zjp-CN/nvim-cmp-lsp-rs)
and [ryo33](https://github.com/ryo33) for [nvim-cmp-rust](https://github.com/ryo33/nvim-cmp-rust),
which inspired this plugin.

## License

[MIT](LICENSE)
