# Completion

`after/plugin/completion.lua` configures native popup completion and enables LSP
completion for attached clients that support it. `after/plugin/pairs.lua` sets up
Blink pairing, which replaces the insert-mode `<CR>` mapping during setup.
Completion therefore captures the startup `<CR>` and `<Right>` mappings once at
`VimEnter`, after both configurations have finished. Either script can run first.

The wrappers accept a selected popup candidate with `<C-y>`. With no popup or no
selected candidate, each wrapper calls its captured global Lua expression callback
once, or returns a captured expression mapping's RHS unchanged. It does not
evaluate Vimscript expressions. Missing or unsupported mappings fall back to the
original key. Buffer-local mappings are outside this composition's contract.

Both setups must finish before `VimEnter`. The one-shot hook does not observe
later mapping changes: a provider that remaps either key after the event can
replace completion acceptance. Sourcing completion after startup does not install
the wrappers immediately; its hook waits for a `VimEnter` event.

Verify both configuration orders, the one-shot hook, popup acceptance, fallback,
and LSP completion conversion without installing packages:

```sh
nvim --headless -u NONE -i NONE -l tests/completion.lua
nvim --headless -n -u NONE -i NONE -c 'luafile tests/autocomplete.lua'
```
