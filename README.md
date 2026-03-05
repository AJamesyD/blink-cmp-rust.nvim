# blink-cmp-rust.nvim

[![CI](https://github.com/AJamesyD/blink-cmp-rust.nvim/actions/workflows/ci.yml/badge.svg?branch=mainline)](https://github.com/AJamesyD/blink-cmp-rust.nvim/actions/workflows/ci.yml)

Rust-aware completion sorting for [blink.cmp](https://github.com/Saghen/blink.cmp).

When you type `my_struct.` in Rust, rust-analyzer returns completions in an order dominated by fuzzy match score.
Its own relevance adjustments are small (-1 for imports, -5 for traits) and easily overridden,
so `clone()`, `into()`, and Deref-forwarded methods regularly appear above the methods you actually defined on the type.
This plugin sorts completions by category (your methods first, trait noise last) with hard boundaries that fuzzy score cannot override.

## What changes

- **Your methods first.** Methods from `impl MyStruct` appear above trait methods like `clone()` or `eq()`.
- **Imported items first.** Completions already in scope appear above those that would trigger an auto-import.
- **Noise sinks to the bottom.** Common trait methods (`Clone`, `Copy`, `Default`, `From`, `Into`, ...),
  Deref/Borrow-forwarded methods, postfix completions, and underscore-prefixed items are pushed to the end.
- **Unwanted imports hidden.** Optionally filter out completions from specific import paths entirely.

Every feature can be toggled independently. The plugin only activates in Rust files; other filetypes are completely unaffected.

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
    -- true:  impl MyStruct methods appear above trait methods
    -- false: inherent and trait methods are interleaved by fuzzy score
    inherent_first = true,

    -- true:  already-imported items appear above auto-import suggestions
    -- false: imported and not-yet-imported items are interleaved by fuzzy score
    inscope_first = true,

    -- true:  postfix completions (e.g. .if, .match, .let) sink to the bottom
    -- false: postfix completions sort normally
    deprioritize_postfix = true,

    -- true:  common trait methods (Clone, Copy, Drop, ToString, ToOwned,
    --        PartialEq, PartialOrd, AsRef, AsMut, From, Into, TryFrom,
    --        TryInto, Default) sink to the bottom
    --        (Deref/Borrow have their own flags and are not included here)
    -- false: common trait methods sort like any other trait method
    deprioritize_common_traits = true,

    -- true:  methods available through Deref/DerefMut coercion (e.g. str
    --        methods on String) appear below the type's own methods
    -- false: deref-forwarded methods sort like inherent methods
    deprioritize_deref = true,

    -- true:  methods from Borrow/BorrowMut appear below the type's own methods
    -- false: borrow-forwarded methods sort like inherent methods
    deprioritize_borrow = true,

    -- true:  _prefixed items (e.g. _private_field) sink to the bottom
    -- false: underscore-prefixed items sort normally
    deprioritize_underscore = true,

    -- Additional traits to treat as "common" (deprioritized).
    -- Useful for traits that are rarely the completion you want:
    --   extra_common_traits = { "Debug", "Display", "Iterator" }
    extra_common_traits = {},

    -- Import path prefixes to filter out entirely (completions are removed,
    -- not just deprioritized). Matches against the full import path:
    --   filter_imports = { "tokio::runtime" }  -- hides tokio::runtime::* re-exports
    --   filter_imports = { "std::os" }         -- hides all std::os::* completions
    filter_imports = {},
  },
}
```

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

Within each tier, blink.cmp's normal fuzzy scoring applies. Disabled tiers (via config) are skipped, so items in those categories sort by fuzzy score as if the plugin weren't installed.

## Troubleshooting

### Completions look the same after installing

- **Check your filetype.** Run `:set ft?` in a Rust buffer. It should print `filetype=rust`. The plugin does nothing in other filetypes.
- **Check your blink.cmp version.** This plugin requires v1.8.0+ for `fuzzy.sorts` function support. Older versions silently ignore the custom sort.
- **Check that setup ran.** With lazy.nvim, `opts = {}` in the dependency spec is enough. Other plugin managers may need an explicit `require("blink-cmp-rust").setup()` call.

### Verifying the plugin is active

`vim.print` inside completion callbacks is swallowed by blink.cmp's UI. Use file-based logging to inspect what the plugin sees:

```lua
-- Add temporarily inside the transform_items wrapper in your blink.cmp config:
vim.fn.writefile(
  { vim.inspect(items[1]) },
  "/tmp/blink-rust-diag.log", "a"
)
```

If items have a `_rust` field in the output, the plugin is classifying them correctly.

## Credits

Thanks to [zjp-CN](https://github.com/zjp-CN) for [nvim-cmp-lsp-rs](https://github.com/zjp-CN/nvim-cmp-lsp-rs)
and [ryo33](https://github.com/ryo33) for [nvim-cmp-rust](https://github.com/ryo33/nvim-cmp-rust),
which inspired this plugin.

## License

[MIT](LICENSE)
