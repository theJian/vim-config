# better_statusline

`lua/better_statusline.lua` supplies the global statusline, per-window bars, and clickable tabline using native Neovim 0.12 statusline formatting. `lua/ui.lua` calls `setup()`; no statusline plugin is required. Highlight links follow the current colorscheme, with quiet dot separators. Window bars use the colorscheme’s `WinBar` and `WinBarNC` highlights without overriding them.

## Information

The replacement preserves the information configured in the former lualine setup:

- Global statusline: editor mode, Git branch (short commit ID when detached), saved-file added/changed/removed line counts, cursor line and byte column, and local time in hours/minutes.
- Window bars: relative filename, `●` for modified, a lock for readonly or nonmodifiable buffers, all four diagnostic severity counts, attached LSP names joined with `+`, progress spinner/completion check, and filetype. Inactive windows retain their own information. Unnamed buffers display `- NO NAME -`; terminal windows have no bar.
- Tabline: tab number, name, and `[+]` when any displayed buffer in the tab is modified. Names honor `t:tabname`, otherwise use the selected buffer's basename (with help, terminal, and Fugitive labels). Native tab targets support mouse switching. The tabline appears with two or more tabs; native truncation favors the active tab on narrow screens.

Diff counts deliberately match lualine's default: saved worktree content compared with the index. Unsaved edits and staged-only changes do not contribute. Git commands run without a shell, external diff helpers, or textconv. Gitsigns supplies branch data when available; asynchronous Git discovery provides a fallback, including worktrees and detached HEADs. Non-repositories simply omit Git information.

## Refresh and performance

`statusline()`, `winbar()`, and `tabline()` return cached formatting strings. Rendering does not launch processes, read files, enumerate tabs, count diagnostics, or query LSP clients. Cursor position uses native `%l`/`%c` fields, so cursor movement needs no Lua refresh handler. There are no `TextChanged` or `CursorMoved` hooks.

Relevant events coalesce into one refresh after 40 ms. Refreshes rebuild window and tab metadata, so their cost scales with open windows/tabs and attached clients. This work still runs on Neovim's main loop; it is not a claim of zero latency under arbitrary workloads. Git processes are asynchronous with timeouts; diff stdout is consumed incrementally and only hunk counts are retained. Saved-file diff caches refresh on buffer entry, write, focus return, Gitsigns updates, and Fugitive changes. Branch fallback queries are throttled to at most one per directory per two seconds during refreshes.

One one-second timer checks for a minute change or outstanding LSP work. Idle ticks do not rebuild or redraw bars. Progress animation advances once per second to keep redraw traffic low. LSP work is tracked by client/token, so overlapping tasks complete independently. Completion markers remain until the client exits. Repeated `setup()` replaces timers/autocommands, and exit closes the timer. Late async results from earlier setups or invalidated diff requests are discarded.

`require('better_statusline').refresh()` requests a coalesced refresh, useful after changing `t:tabname` directly. It does not invalidate Git caches. No compatibility layer for lualine is provided.

## Mode colors

Pass `mode_colors` to `setup()` to customize the mode label. Other components keep their own highlights. Values can be highlight-group names or `nvim_set_hl` attribute tables:

```lua
require('better_statusline').setup {
    mode_colors = {
        normal = 'StatusLine',
        insert = { fg = '#0d50c5', bold = true },
        visual = { fg = '#7a5000', bg = '#ffebd1' },
        replace = 'DiagnosticError',
    },
}
```

Supported families are `normal`, `insert`, `visual` (including line/block), `select`, `replace`, `command` (including prompts), `terminal`, and `operator`. Select defaults to the configured visual color; operator defaults to normal. Other unspecified families use `StatusLine`. Attribute tables and named groups inherit missing attributes from `StatusLine`, preserving its background when only a foreground is supplied. Missing named groups fall back to `StatusLine`.

Colors are prepared on setup and colorscheme changes; the existing coalesced `ModeChanged` refresh chooses a cached highlight without defining highlights during rendering. Calling `setup()` again replaces the configuration; `setup()` without arguments restores defaults. This repository configures Moonwalk's custom `StatusNormal`, `StatusInsert`, `StatusVisual`, `StatusReplace`, `StatusCommand`, and `StatusTerminal` groups in `lua/ui.lua`; these are not standard Neovim groups.

## Verification

Run from the repository root:

```sh
nvim --headless -u NONE -i NONE -l tests/better_statusline.lua
```

The test creates a disposable Git repository and checks saved diff counts with inter-hunk context configured, staging/unstaging cache invalidation, branch/detached HEAD, native cursor fields, split-specific window bars, terminal exclusion, modified tabs, literal percent/Unicode filenames, diagnostics, concurrent LSP progress, and repeated setup. It also forbids expensive service calls while running 10,000 cached render triplets and prints the elapsed time; this is a renderer microbenchmark, not an end-to-end typing latency measurement.

For visual inspection, start the normal configuration, open splits and multiple tabs, edit a file, and enter insert/visual/terminal modes. Check diagnostics and LSP progress with an attached server, and resize the terminal to inspect truncation. `tests/startup.lua` asserts that better_statusline loads and lualine does not.

An already installed lualine package can cause `vim.pack` to restore its lockfile entry during package metadata repair. It remains unloaded; the replacement does not delete existing packages from your local Neovim data directory.
