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

## Upstream sorting improvements into rust-analyzer

The plugin's sorting logic (fields > inherent methods > trait methods > common traits,
keyword/import deprioritization) addresses gaps in rust-analyzer's `CompletionRelevance`
scoring. Three independent Neovim plugins converge on the same heuristics, suggesting
these belong in the server, not in client-side workarounds.

Approach: fix rust-analyzer's defaults directly rather than adding config. No LSP server
exposes scoring config as a precedent. Open a Zulip thread in `#t-compiler/rust-analyzer`
before submitting PRs.

If upstream lands, this plugin could simplify to frecency/recency layering only
(see blink.cmp v2 frecency above).
