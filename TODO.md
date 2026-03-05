# TODO

Ideas and potential improvements. Not commitments.

## score_offset mode

Use `item.score_offset` in `transform_items` to encode tier priority numerically,
instead of a custom `fuzzy.sorts` comparator.

- Removes the `fuzzy.sorts` wiring from user config entirely
- Tradeoff: soft tier boundaries (fuzzy score can theoretically bleed across) vs the
  current hard boundaries from `compare`
- Could offer as opt-in, or make it the default if the gaps are large enough to be
  effectively hard

## Kind-based deprioritization for non-dot contexts

Outside dot-completion (statement level, expressions, match arms), the plugin barely
does anything. Everything lacks trait annotations, so nearly all items land in the
same tier.

Plan: add `deprioritize_*` flags for the noisiest kinds:

- `deprioritize_keywords` — typing `le` and getting `let` above `length`
- `deprioritize_text` — rarely useful in Rust

A full configurable `kind_priority` list (like nvim-cmp-lsp-rs offered) is also an
option, but it cuts against the "push noise down" philosophy and risks the same
ordering conflicts the old nvim-cmp config ran into. The targeted flags cover the
common complaints without that complexity.

## blink.cmp v2 frecency

v2 roadmap ([#1059](https://github.com/Saghen/blink.cmp/issues/1059)) plans opt-out
frecency for languages with good LSP sorting (rust-analyzer mentioned).

Worth checking that the plugin composes well when v2 ships.
