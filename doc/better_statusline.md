# better_statusline

`lua/better_statusline.lua` supplies the global statusline, per-window bars, and clickable tabline using native Neovim 0.12 statusline formatting. This configuration already calls `setup()` in `lua/ui.lua`; edit that existing call to customize mode colors. No separate statusline plugin is required. Highlight links follow the current colorscheme. Window bars use the colorscheme’s `WinBar` and `WinBarNC` highlights without overriding them.

## Information

The bars display the following information:

- Global statusline: editor mode, Git branch (short commit ID when detached), the current file's saved added/changed/removed line counts, and cursor line and byte column.
- Window bars: relative filename, modified and readonly/nonmodifiable markers, diagnostic counts by severity, attached LSP names, a text shimmer on busy servers, and filetype. Inactive windows retain their own information. Unnamed buffers receive a placeholder label; terminal windows have no bar.
- Tabline: tab number, name, and a modified marker when any displayed buffer in the tab is modified. Names honor `t:tabname`, otherwise use the selected buffer's basename (with special labels for help and terminal buffers). Native tab targets support mouse switching. The tabline appears with two or more tabs; native truncation favors the active tab on narrow screens.

Diagnostic icons use standard Unicode geometric shapes and need no Nerd Font. Other icons require a compatible font.

Diff counts compare saved worktree content with the index. Unsaved edits, staged-only changes, and untracked files do not contribute. Gitsigns supplies branch data when available; asynchronous Git discovery provides a fallback, including worktrees and detached HEADs. Git must be on PATH for lookups; unavailable Git information is omitted. Gitsigns is optional for data, but change-count colors link to `GitSignsAdd`, `GitSignsChange`, and `GitSignsDelete`. Without those groups, their intended colors may be absent.

## Public API

For standalone use, initialize the module once in your Neovim configuration:

```lua
local bars = require('better_statusline')
bars.setup() -- Install all bars with default mode colors.

vim.t.tabname = 'Review'
bars.refresh() -- Queue an update after a direct metadata change.
```

`setup(opts?)` takes an optional `mode_colors` table, described below. It replaces the
statusline and tabline options and manages non-floating windows' winbars, including
windows opened later. It sets a global statusline and shows tabs only when multiple
tabs exist. Avoid combining it with another module that manages the same options.
Repeated calls replace the previous configuration and clear the caches; calling
`setup()` without options restores default mode colors. Invalid mode
family names or values other than strings/tables raise an error before replacement.

`refresh()` returns immediately and combines pending requests into one update. It is
a no-op before setup and does not force a Git rescan or invalidate Git caches.

`statusline()`, `winbar()`, and `tabline()` are render callbacks installed by setup;
you normally do not call them yourself. They return native Neovim format strings,
not plain text, and do not refresh their caches. All return empty strings before
setup. `winbar()` selects Neovim's render target, falling back to the current window
if no valid target is available; terminals and uncached windows return empty strings.

## Automatic updates

Editor events combine into deferred updates, while redraws use cached strings.
Cursor positions remain current through Neovim's native formatting. Git queries run
asynchronously, so branch and change counts may appear shortly after other content.
Saved-file counts are refreshed on buffer entry, write, focus return, and supported
Git plugin events. Branch lookups are throttled to avoid starting Git on every event.

Language server names animate while the server reports unfinished work. Idle servers
do not trigger animation redraws. See `refresh()` above for direct metadata changes.

## Mode colors

Edit `mode_colors` in the existing `lua/ui.lua` setup call to customize the mode label. Other components keep their own highlights. Values can be highlight-group names or `nvim_set_hl` attribute tables:

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

Colors follow colorscheme changes. This repository uses Moonwalk's custom mode
highlight groups in `lua/ui.lua`; the example above uses standard groups and explicit
colors so it can also be used with other themes.

## Verification

Run from the repository root:

```sh
nvim --headless -u NONE -i NONE -l tests/better_statusline.lua
```

The test uses a disposable Git repository and checks rendering, Git updates, LSP
progress, and repeated setup. It also verifies that cached render callbacks do not
perform expensive data collection.

For a visual check, open splits and tabs, edit a file, switch modes, and resize the
terminal. With a language server attached, check diagnostics and progress animation.
