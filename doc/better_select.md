# better_select

A single-file Neovim picker for arbitrary Lua values. Search lists with fuzzy
matching, query live providers, mark multiple items, show previews, and send
results to quickfix. Selection callbacks receive the original values and their
source indices.

## Installation

Requires Neovim 0.12 or newer with ui2 enabled. Copy `lua/better_select.lua` into
your Neovim configuration's `lua/` directory, then enable ui2 in your startup
configuration, and load your keyboard bindings from `lua/keymaps.lua`:

```lua
require('vim._core.ui2').enable({})
```

The module has no plugin dependencies. ui2 is experimental; changes to Neovim's
internal APIs may require updates to the picker.

## Quick start

```lua
local select = require 'better_select'

select.open {
    prompt = 'Environment',
    source = { 'development', 'staging', 'production' },
    on_choice = function(value, index)
        vim.notify(('Selected %s at index %d'):format(value, index))
    end,
}
```

For records, supply `format_item` to choose the text to display and search:

```lua
require('better_select').open {
    prompt = 'Project',
    source = {
        { name = 'Website', path = '~/projects/website' },
        { name = 'Tools', path = '~/projects/tools' },
    },
    format_item = function(project) return project.name end,
    on_choice = function(project)
        vim.api.nvim_set_current_dir(vim.fn.expand(project.path))
    end,
}
```

Values retain their identity, including tables and metatables. Strings, numbers,
and booleans are supported; labels default to `tostring`. Control characters in
labels and prompts are escaped so each occupies one row.

Static lists are fuzzy-filtered locally. Equal scores preserve source order.
Prefix a query with `/pattern/` to restrict matches by a Lua pattern before fuzzy
filtering: `/^src/handler` searches for `handler` in labels beginning with `src`.

## Source providers

A function source receives `(query, emit, ctx)`. It may return a list immediately,
return a cancellation function for asynchronous work, or return `nil` and call
`emit(items, err?)` later. Each emission replaces the complete result list.

Providers use live mode by default: prompt changes request new results, and the
picker preserves the provider's result order. Requests are debounced by 30 ms;
the initial request runs immediately. Old requests are cancelled when possible,
and late results are ignored after a newer request or closure.

Use `live = false` to load a provider once and fuzzy-filter its values locally.
The provider receives an empty query in this mode. Call `handle:refresh()` to
reload it.

```lua
require('better_select').open {
    prompt = 'Buffer',
    live = false,
    source = function()
        return vim.tbl_filter(function(buf) return vim.bo[buf].buflisted end,
            vim.api.nvim_list_bufs())
    end,
    format_item = function(buf) return vim.api.nvim_buf_get_name(buf) end,
    preview_item = function(buf) return { buf = buf } end,
    on_choice = function(buf) vim.api.nvim_set_current_buf(buf) end,
}
```

An asynchronous provider can stop external work when its request becomes obsolete:

```lua
require('better_select').open {
    prompt = 'Tracked file',
    debounce = 50,
    source = function(query, emit, ctx)
        local job = vim.system({ 'git', 'ls-files' }, { text = true }, function(result)
            vim.schedule(function()
                if ctx.cancelled() then return end
                if result.code ~= 0 then emit(nil, result.stderr); return end
                local paths = vim.split(result.stdout, '\n', { trimempty = true })
                emit(query == '' and paths or vim.fn.matchfuzzy(paths, query))
            end)
        end)
        return function() job:kill(15) end
    end,
    on_choice = function(path)
        vim.api.nvim_cmd({ cmd = 'edit', args = { path } }, {})
    end,
}
```

`emit` schedules result handling on Neovim's main loop. Schedule any other Neovim
API calls yourself when working in a fast event. `ctx.search` is the picker
handle; `ctx.cancelled()` tells the provider whether its request is obsolete.

Marks survive local filtering, including when marked values become hidden.
Replacing results clears marks and selection. Pending live queries clear old
results immediately so a stale value cannot be accepted. Switching between live
and local modes preserves the query; local mode filters the latest loaded list.

## Controls

| Key | Action |
| --- | --- |
| Up / Down | Move selection within the list |
| Enter | Accept the selected value |
| Escape | Cancel |
| Tab | Toggle the selected value's mark |
| Ctrl-g | Switch a provider between live and local modes |
| Ctrl-l | Toggle the preview supplied by `preview_item` |
| Ctrl-q | Send marked values, or all matches, to quickfix using `to_quickfix` |
| Ctrl-s / Ctrl-v / Ctrl-t | Run a custom `split`, `vsplit`, or `tabnew` action |

Only one picker is active at a time. Opening another cancels the current picker.
Leaving insert mode or the picker window also cancels it. Accepting an empty list
keeps the picker open. Editor options and buffer-local mappings are restored
before choice and cancellation callbacks run.

## Configuration

`setup(options)` configures defaults. `open(options)` accepts per-picker overrides;
`source` is required on each call. Keyboard bindings are configured in
`lua/keymaps.lua`, using buffer-local aliases to `<Plug>(acme-better-select-ACTION)`.
Action names use hyphens, for example `<Plug>(acme-better-select-toggle-live)`.
The module defines only these action mappings, including custom `actions`.
The `on_open(search)` callback configures picker-local bindings after opening.
`require('better_select').current()` returns the active handle.
`keymaps.lua` installs aliases with `unique = true` and registers their cleanup
in `search.view.restore`. Conflicting buffer-local mappings cause an error;
global mappings remain intact and are shadowed while the picker is open.

```lua
require('better_select').setup {
    opts = {
        preselect = true,
        bottom = true,
        shrink = true,
        prompt_prefix = '›',
        prompt_title = true,
        pointer = '»',
        marker = '│',
        info_list = { 'list' },
    },
    win = { height = 0.4, hide_statusline = false },
}
```

`win.height` is a fraction of editor height when at most 1, otherwise a row count.
The picker reserves one row for the prompt and limits its height to the editor.
Set `bottom = false` for a top prompt, `shrink = false` for a fixed list height,
or `preselect = false` to start without a selection. `info_list` supports `list`
for the match/source counts and `index` for the selected match's position.
`default_text` on `open` supplies the initial query.

Highlight groups are `BetterSelectNormal`, `BetterSelectPrompt`,
`BetterSelectSel`, `BetterSelectPointer`, `BetterSelectMatch`,
`BetterSelectMatchSel`, `BetterSelectInfo`, `BetterSelectMark`, and
`BetterSelectMarkLine`. Defaults are reapplied on colorscheme changes without
overriding user-defined groups.

## Callbacks and extensions

| Option | Contract |
| --- | --- |
| `format_item(value, index)` | Return the display/search label as a string |
| `on_choice(value, index, marked, handle)` | Receive the original value, 1-based source index, and marked values in source order |
| `on_cancel(handle)` | Run once when the picker is cancelled |
| `preview_item(value, index, handle)` | Return `{ buf = buffer, pos = { line, col }, pos_end = { line, col } }` or `nil`; positions are optional, lines are 1-based, and columns are 0-based byte offsets |
| `get_icon(entry)` | Return an icon and its highlight group |
| `hl_item(entry)` | Return `{ { { start_byte, end_byte_exclusive }, group }, ... }` for label highlights |
| `to_quickfix(value, index)` | Return a Neovim quickfix entry |
| `sorter(entries, query)` | Return ordered `{ source_index, character_positions, score }` matches; positions are 0-based character offsets |
| `win.preview_opts(view)` | Return floating-window overrides for the preview |

Entries passed to icon, highlight, and sorter hooks contain
`{ id = source_index, v = original_value, text = formatted_label }`.
`require('better_select').sorter` exposes the default pattern/fuzzy sorter.
Preview buffers belong to the caller; the picker only manages their windows.

Custom actions receive the handle and can override built-in action names. Close
the picker before changing editor windows:

```lua
require('better_select').open {
    source = { 'README.md', 'init.lua' },
    actions = {
        split = function(handle)
            local entry = handle:get_current()
            if not entry then return end
            handle:close()
            vim.api.nvim_cmd({ cmd = 'split', args = { entry.v } }, {})
        end,
    },
}
```

## Handle API

`open(options)` returns a handle with these methods:

| Method | Behavior |
| --- | --- |
| `set_query(query)` | Set the query and update results |
| `refresh(immediate?)` | Request provider results again; `true` skips debouncing |
| `get_current(index?)` | Return the selected entry, or an entry at a given source index |
| `get_marked()` | Return marked original values in source order |
| `action(name)` | Run a built-in or custom action |
| `toggle_live()` | Switch a function source between live and local modes |
| `set_quickfix()` | Convert marked values, or all matches, using `to_quickfix` |
| `accept()` | Close and invoke `on_choice` if an entry is selected |
| `cancel()` | Close and invoke `on_cancel` once |
| `close()` | Close without invoking choice or cancellation callbacks |

## Standard selection interface

To use the picker for `vim.ui.select`, opt in explicitly:

```lua
vim.ui.select = require('better_select').select
```

The adapter preserves the standard `(value, index)` callback, including
`(nil, nil)` on cancellation. It can also be called directly as
`require('better_select').select(items, options, on_choice)`.

## Development

Run the integration suite from a directory containing `lua/better_select.lua`
and `tests/`:

```sh
nvim --headless -u NONE -i NONE -l tests/better_select.lua
```

Run the attached UI checks in a terminal; Neovim exits automatically afterward:

```sh
nvim -u NONE -i NONE -c 'luafile tests/better_select_ui.lua'
```
