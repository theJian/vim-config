# AGENTS.md

This file provides guidance to coding agents working in this repository. Paths below are relative to the repository root.

Keep module documentation in `doc/`. Keep repository-level documentation such as `README.md` and `AGENTS.md` at the repository root. Write self-contained descriptions of this configuration and use Vim key notation such as `<leader>p` and `<leader><Tab>`; avoid comparisons with other editor configurations.

## Overview

This is a minimalist Neovim configuration written in Lua that uses Neovim's built-in `vim.pack` (Neovim 0.12+). The configuration focuses on essential functionality while maintaining a clean, minimal setup.

## Architecture

### Core Structure

- `init.lua` - Main entry point that loads core modules
- `lua/options.lua` - Basic Neovim options and settings
- `lua/keymaps.lua` - Keyboard mappings and leader key setup
- `lua/autocmds.lua` - Automatic commands for file handling
- `lua/ui.lua` - UI configuration including colorscheme and signcolumn
- `lua/packages.lua` - Plugin specifications and native build hooks
- `lua/better_select.lua` - Native ui2 picker; see `doc/better_select.md`
- `lsp/*.lua` - Native LSP server configurations

### Native Projects and Workspaces

- `lua/projects.lua` implements the `<leader>p` project menu without additional plugins.
- `lua/workspaces.lua` implements `<leader><Tab>` using named tabs, buffer membership, and session snapshots.
- `lua/workspace_store.lua` stores data-only JSON under `stdpath('state')/workspaces/` and routes lists through `better_select`.
- Project-local settings use `.nvim-project.json`; recovered unsaved text is protected from auto-save until edited.
- Preserve transactional restore, shared-buffer ownership, and the previous saved session when exiting an empty session.
- Project commands follow the current file’s root; empty and special buffers fall back to the workspace root. Vim counts select alternate actions such as workspace cloning.
- See `doc/projects-workspaces.md` for all bindings, persistence behavior, and test commands.

### Plugin Configuration

- `lua/plugins/init.lua` - Main plugin loader that initializes all plugins
- `lua/plugins/*.lua` - Individual plugin configurations:
  - `lsp.lua` - Native LSP activation and attachment mappings; `mason.lua` manages server installation
  - `completion.lua` - Native fuzzy completion and snippet navigation
  - `treesitter.lua` - Syntax highlighting
  - `gitsigns.lua` - Git integration
  - `dap.lua` - Debug adapter protocol
  - `formatter.lua` - Code formatting
  - `lint.lua` - Linting configuration
  - Other specialized plugin configs

### Plugin Management (vim.pack)

- Plugin specifications are in `lua/packages.lua`; the colorscheme, fff.nvim, and parinfer-rust also use `vim.pack.add` in their existing modules.
- Missing plugins install automatically; `nvim-pack-lock.json` preserves their revisions.
- Plugins live in `stdpath('data')/site/pack/core/opt/`.
- Native build hooks run on install and update; Cargo is required (blink.pairs requires nightly Rust).
- When upgrading an existing checkout, move old `pack/packman/start/` plugins outside `pack/*/start/` to prevent duplicate loading. Keep any separately installed plugins you still use.

## Key Features

### LSP and Development Tools

- Mason.nvim for LSP server management
- Treesitter for syntax highlighting
- nvim-dap for debugging
- nvim-lint for linting
- formatter.nvim for code formatting

### UI/UX

- nvim-moonwalk colorscheme
- lualine.nvim for statusline
- indent-blankline.nvim for indentation guides
- Native Treesitter expression folding
- Oil.nvim for file browser
- gitsigns.nvim for git integration

### Editor Enhancements

- nvim-surround for surrounding characters
- nvim-paredit for structured editing (Lisp/Clojure)
- grug-far.nvim for search and replace
- fff.nvim for file finding and live grep
- Native ui2 `better_select` for project/workspace and general selection lists

## Keymaps Reference

### Leader Key

- Leader is `<Space>`
- Local leader is `<Space>`

### Navigation

- `gh` / `gl` - Go to line start/end (first/last non-blank char)
- `j`/`k` - Move by visual line (handles wrapped lines with count support)
- `<leader>wj/wk/wl/wh` - Navigate between windows
- `<C-q>` - Close window
- `<CR>` - Clear active search highlights; otherwise use normal Enter behavior

### Window Management

- `<leader>ws` / `<leader>wv` - Horizontal/vertical split
- `<leader>t` - New tab (automatically registered as a workspace)
- `<leader><Tab>.` - Switch workspace
- `<leader>pp` - Switch project and select a file
- `<leader>,` / `<leader>bb` - Select a workspace buffer
- `<leader>x` - Close buffer (preserves window)

### Custom Behaviors

- `;` / `:` - Swapped (semicolon enters command mode)
- `<Tab>` / `<S-Tab>` in insert mode - Navigate completion, then snippet tabstops
- `<CR>` in insert mode - Accept a selected completion; otherwise preserve Enter behavior
- `<C-a>` / `<C-e>` in command line - Move to start/end
- `<Esc>` in terminal mode - Exit terminal mode; `<C-[>` sends a raw Escape to the terminal program

### LSP Keymaps (set on LspAttach)

- `K` - Hover
- `gd` - Go to definition
- `gD` - Go to declaration
- `gs` - Signature help
- `g0` - Show diagnostics in location list
- `grh` - Toggle inlay hints
- `gK` - Toggle diagnostic virtual lines
- `<leader>wn/wd/wL` - Add/remove/list LSP workspace folders (uppercase `L`; lowercase `wl` navigates windows)

### Folding

- Use native fold commands such as `za`, `zo`, and `zc`; no custom fold-toggle mapping is configured.

## Common Development Commands

### Plugin Management

```vim
:lua vim.pack.add({ 'https://github.com/user/repo' }) " Also add to config to persist loading
:lua vim.pack.update()                              " Review and update plugins
:lua vim.print(vim.pack.get())                      " List managed plugins
:lua vim.pack.del({ 'plugin-name' })                " Remove from config first
```

### LSP Operations

```vim
:LspInfo                              " Show attached LSP servers
:lua vim.lsp.buf.format()             " Format current buffer
:lua vim.lsp.buf.rename()             " Rename symbol
:lua vim.lsp.buf.code_action()        " Code actions
```

### Mason (LSP Server Management)

```vim
:Mason                                " Open Mason UI
:MasonInstall <server>                " Install LSP server
:MasonUninstall <server>              " Uninstall LSP server
```

### Debugging (DAP)

```vim
:lua require('dap').toggle_breakpoint()  " Toggle breakpoint
:lua require('dap').continue()           " Start/continue debugging
:lua require('dap').step_over()          " Step over
:lua require('dap').step_into()          " Step into
```

### Treesitter

```vim
:TSInstall <language>                  " Install treesitter parser
:TSUninstall <language>                " Uninstall parser
:InspectTree                           " Inspect the current syntax tree
```

### File Operations

```vim
:Oil                                   " Open oil file browser
:Gitsigns                              " Git operations (diff, blame, etc.)
```

## Configuration Notes

- Uses space as leader key
- Default shell is fish
- Spell language is English US; spell checking is not globally enabled and can be set per project
- Uses system clipboard on macOS only
- Folding enabled with treesitter
- Diagnostic virtual text and virtual lines are disabled by default; `gK` toggles virtual lines

### Auto-save Behavior
Auto-save is configured in `lua/autocmds.lua` with the following characteristics:

- Triggered on `InsertLeave` and `TextChanged` events
- Runs directly on these events, without a debounce timer
- Checks for Treesitter syntax errors before saving; absence of a parser does not block saving
- Recovered session text is exempt until edited; explicit writes still work
- Won't save unnamed, unmodified, readonly, or special buffers

### Important Options

- `virtualedit = 'block,onemore'` - Allow cursor past end of line
- `wrapscan = false` - Search stops at end of file (doesn't wrap)
- `hidden = true` - Hide changed buffers instead of closing
- `confirm = true` - Ask confirmation when quitting with unsaved changes
- `updatetime = 30` - Short idle interval for CursorHold and related editor behavior
- `lazyredraw = true` - Performance optimization

## Verification

Run from the repository root. The workspace tests isolate persistence in temporary directories.

```sh
nvim --headless -u NONE -i NONE -l tests/workspaces.lua
nvim --headless -u NONE -i NONE -l tests/workspaces_restart.lua
nvim --headless -u NONE -i NONE -l tests/workspaces_review.lua
nvim --headless -u NONE -i NONE -l tests/better_select.lua
nvim --headless -u NONE -i NONE -l tests/completion.lua
```

Run keyboard/UI tests in an attached terminal:

```sh
nvim -u NONE -i NONE -c 'luafile tests/workspaces_ui.lua'
nvim -u NONE -i NONE -c 'luafile tests/better_select_ui.lua'
```

`tests/startup.lua` exercises the full configuration and installed plugins. For isolated startup checks, set `XDG_CACHE_HOME`, `XDG_STATE_HOME`, and `NVIM_LOG_FILE` to temporary locations, then run `nvim --headless -u ./init.lua -i NONE -c 'luafile tests/startup.lua'`. Full startup can install missing configured plugins; use the `-u NONE` tests when plugin loading is unnecessary.

## File Structure

```text
.
├── AGENTS.md                  # Repository-wide agent instructions
├── README.md                  # Configuration overview
├── init.lua
├── doc/                       # Module documentation
│   ├── better_select.md
│   └── projects-workspaces.md
├── lsp/                       # Native LSP server configurations
├── lua/
│   ├── options.lua
│   ├── keymaps.lua
│   ├── autocmds.lua
│   ├── ui.lua
│   ├── packages.lua
│   ├── better_select.lua
│   ├── projects.lua
│   ├── workspaces.lua
│   ├── workspace_store.lua
│   └── plugins/               # Individual plugin configurations
├── tests/                     # Headless and attached-terminal tests
└── nvim-pack-lock.json
```
