# Generic picker

`require('picker')` selects arbitrary Lua values using a command-area prompt,
a list of matches, fuzzy filtering, marking, and optional previews. Requires
Neovim 0.12+ with ui2 enabled. This repository enables ui2 in `lua/ui.lua`;
when using the module in another configuration, enable it before opening a picker:

```lua
require('vim._core.ui2').enable({})
```

The renderer is adapted from [artio.nvim](https://github.com/comfysage/artio.nvim)
at revision `ebf5ed35bf17babeee20b04129ce60a382214687`; attribution and EUPL-1.2
terms are included in [NOTICE](NOTICE) and [LICENSE](LICENSE).

## Static values

```lua
local picker = require 'picker'
picker.pick {
    prompt = 'Environment',
    source = {
        { name = 'Development', url = 'http://localhost:3000' },
        { name = 'Staging', url = 'https://staging.example.com' },
    },
    format_item = function(env) return env.name end,
    on_choice = function(env, index, marked)
        -- env is the original table; index is its 1-based source position.
        vim.notify(env.url)
    end,
}
```

Strings, numbers, booleans, and records are supported. `format_item` defaults to
`tostring`; provide it for readable record labels. Newlines/control characters
are displayed as escaped text, so every value occupies one row. Equal fuzzy
scores preserve source order. Prefix a query with `/lua_pattern/` to restrict
fuzzy matches: `/^src/handler` fuzzy-matches `handler` only in labels starting with `src`.

## Computed sources

A provider receives `(query, emit, ctx)` and can either return a list or emit
lists asynchronously. Providers default to live mode: changing the prompt
requests new results, whose order is preserved without additional fuzzy sorting.
Use `live = false` to load once and fuzzy-filter locally; `handle:refresh()`
reloads that source. The provider receives an empty query string in this mode.
The returned list must contain the original values; `format_item` supplies their
display labels, and `on_choice` receives the selected value without copying it.

```lua
local picker = require 'picker'
picker.pick {
    prompt = 'Buffers',
    source = function()
        return vim.tbl_filter(function(buf) return vim.bo[buf].buflisted end,
            vim.api.nvim_list_bufs())
    end,
    live = false,
    format_item = function(buf) return vim.api.nvim_buf_get_name(buf) end,
    preview_item = function(buf) return { buf = buf } end,
    on_choice = function(buf) vim.api.nvim_set_current_buf(buf) end,
}
```

## Async/live sources

```lua
local picker = require 'picker'
picker.pick {
    prompt = 'Tracked files',
    debounce = 50,
    source = function(query, emit, ctx)
        local job = vim.system({ 'git', 'ls-files' }, { text = true }, function(result)
            vim.schedule(function()
                if ctx.cancelled() then return end
                if result.code ~= 0 then emit(nil, result.stderr); return end
                local files = vim.split(result.stdout, '\n', { trimempty = true })
                emit(query == '' and files or vim.fn.matchfuzzy(files, query))
            end)
        end)
        return function() job:kill(15) end
    end,
    on_choice = function(path)
        vim.api.nvim_cmd({ cmd = 'edit', args = { path } }, {})
    end,
}
```

Return `nil` when using `emit`, or return a cancellation function to stop pending
work. Each `emit(items, err?)` replaces the complete list; multiple emissions are
allowed. Emissions are scheduled onto Neovim's main loop, including when called
from a fast event. Results from old queries and closed pickers are ignored.
`ctx.cancelled()` reports whether that request has become obsolete. Provider
requests are debounced by 30 ms by default; the initial request runs immediately.
Providers must schedule any Neovim API calls themselves when doing work in a
fast event, before invoking `emit`.

Marks survive local filtering. Replacing the source list clears marks and
selection because the same index can now refer to a different value. While a
new live query is pending, the old results are removed to prevent accepting a
stale value. `<C-g>` switches a provider between live querying and local fuzzy
filtering of its latest results, with separate prompt text for each mode.

## Interaction and hooks

| Key | Action |
| --- | --- |
| Up / Down | Move selection, clamped to the list |
| Enter | Accept the selected item |
| Escape | Cancel |
| Tab | Toggle marking the selected item |
| Ctrl-g | Toggle live/local filtering for providers |
| Ctrl-l | Toggle caller-provided preview |
| Ctrl-q | Export marked items, or current matches, to quickfix if `to_quickfix` is supplied |
| Ctrl-s / Ctrl-v / Ctrl-t | Invoke caller-defined `split` / `vsplit` / `tabnew` actions |

`on_choice(value, source_index, marked_values, handle)` runs after restoring the
editor. Marked values are returned in source order, including hidden matches.
`on_cancel(handle)` runs once on Escape, leaving the picker, or opening another
picker. Accepting an empty list leaves the prompt open. `handle:close()` silently
closes without a choice/cancel callback. Only one picker can be open at a time.

Additional hooks:

- `preview_item(value, index, handle)` returns `{ buf, pos?, pos_end? }` or nil.
  Positions are `{ one_based_line, zero_based_byte_column }`. Buffers belong to
  the caller and are not deleted; the preview window is closed on picker exit.
- `get_icon(entry)` returns `icon, highlight_group`; `entry` is
  `{ id = source_index, v = original_value, text = formatted_label }`.
  For files, this can call `require('mini.icons').get('file', entry.v)`.
- `hl_item(entry)` returns `{ { { start_byte, end_byte_exclusive }, hl_group }, ... }`.
- `to_quickfix(value, index)` returns a Neovim quickfix entry. Generic values
  require this conversion before Ctrl-q can operate.
- `sorter(entries, query)` returns an ordered list of
  `{ source_index, zero_based_character_positions, score }` matches.
  Use `picker.sorter` for the default pattern + fuzzy matcher.
- `actions = { name = function(handle) ... end }` supplies custom actions or
  overrides defaults. `handle:getcurrent()` returns the selected entry;
  `handle:getmarked()` returns marked original values. Use `handle:close()`
  before changing editor windows from a custom action.

`pick` returns a handle with `set_query(query)`, `refresh()`, `action(name)`,
`getcurrent()`, `getmarked()`, `accept()`, `cancel()`, and `close()`.

## UI configuration

`picker.setup` sets defaults; each `pick` call can override them. Mapping
changes merge with defaults; set a mapping to `false` to disable it.

```lua
local picker = require 'picker'
picker.setup {
    opts = {
        preselect = true, bottom = true, shrink = true,
        promptprefix = '', prompt_title = true, pointer = '', marker = '│',
        infolist = { 'list' }, -- 'list' gives (matches/items); 'index' gives [selection]
    },
    win = { height = 0.4, hidestatusline = false },
    mappings = { ['<C-n>'] = 'down', ['<C-p>'] = 'up' },
}
```

Height may be a fraction of the editor (0 < height <= 1) or a number of rows.
`win.preview_opts(view)` can return Neovim floating window options. Highlight
groups use the `Picker` prefix: `Normal`, `Prompt`, `Sel`, `Pointer`, `Match`,
`Mark`, and `MarkLine`. The module uses experimental `vim._core.ui2` internals,
so future Neovim changes may require updating the renderer.

Opt into the standard selection interface explicitly:

```lua
vim.ui.select = require('picker').select
```

No keymaps or selection overrides are installed globally. Buffer-local mappings
and editor options are restored on exit.

## Verification

Run the integration tests from the repository root:

```sh
nvim --headless -u NONE -i NONE -l tests/picker.lua
```
