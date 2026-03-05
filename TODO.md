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

## blink.cmp v2 frecency

v2 roadmap ([#1059](https://github.com/Saghen/blink.cmp/issues/1059)) plans opt-out
frecency for languages with good LSP sorting (rust-analyzer mentioned).

Worth checking that the plugin composes well when v2 ships.
