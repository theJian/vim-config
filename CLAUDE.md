# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a minimalist Neovim configuration written in Lua that uses a custom plugin manager called `packman`. The configuration focuses on essential functionality while maintaining a clean, minimal setup.

## Architecture

### Core Structure
- `init.lua` - Main entry point that loads core modules
- `lua/options.lua` - Basic Neovim options and settings
- `lua/keymaps.lua` - Keyboard mappings and leader key setup
- `lua/autocmds.lua` - Automatic commands for file handling
- `lua/ui.lua` - UI configuration including colorscheme and signcolumn
- `lua/packman.lua` - Custom plugin manager (see Plugin Management below)

### Plugin Configuration
- `lua/plugins/init.lua` - Main plugin loader that initializes all plugins
- `lua/plugins/*.lua` - Individual plugin configurations:
  - `lsp.lua` - LSP configuration with mason.nvim
  - `treesitter.lua` - Syntax highlighting
  - `gitsigns.lua` - Git integration
  - `dap.lua` - Debug adapter protocol
  - `formatter.lua` - Code formatting
  - `lint.lua` - Linting configuration
  - Other specialized plugin configs

### Plugin Management (packman)
This config uses a custom plugin manager called `packman` instead of common alternatives like Packer or Lazy. Key points:

- Plugins are installed to `pack/packman/start/` (autoload) and `pack/packman/opt/` (optional)
- Plugin definitions are stored in `lua/packfile` using the syntax: `Pack { "https://github.com/user/repo" }`
- Use `:lua require('packman').install()` to install from packfile
- Use `:lua require('packman').get('user/repo')` to install single plugins
- Use `:lua require('packman').update()` to update plugins
- Use `:lua require('packman').list()` to list installed plugins

### Packfile Format
The `lua/packfile` defines plugins using a custom DSL:
```lua
Pack {
  "https://github.com/user/repo",
}

Pack {
  "https://github.com/user/optional-plugin",
  opt,  -- Mark as optional (goes to opt/ directory)
}
```

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
- nvim-ufo for folding
- Oil.nvim for file browser
- gitsigns.nvim for git integration

### Editor Enhancements
- nvim-surround for surrounding characters
- nvim-paredit for structured editing (Lisp/Clojure)
- grug-far.nvim for search and replace
- copilot.vim for GitHub Copilot integration

## Keymaps Reference

### Leader Key
- Leader is `<Space>`
- Local leader is `<Space>`

### Navigation
- `gh` / `gl` - Go to line start/end (first/last non-blank char)
- `j`/`k` - Move by visual line (handles wrapped lines with count support)
- `<C-j/k/l/h>` - Navigate between windows
- `<C-q>` - Close window
- `<BS>` - Clear search highlights

### Window Management
- `<leader>h` / `<leader>v` - Horizontal/vertical split
- `<leader>t` - New tab
- `<leader>x` - Close buffer (preserves window)

### Custom Behaviors
- `s` / `ss` / `S` - Edit without yanking (uses black hole register)
- `;` / `:` - Swapped (semicolon enters command mode)
- `*` / `#` in visual mode - Search for selected text (literal search)
- `<Tab>` / `<S-Tab>` in insert mode - Navigate completion menu
- `<C-h/l/k/j>` in command line - Cursor movement

### LSP Keymaps (set on LspAttach)
- `K` - Hover
- `gd` - Go to definition
- `gD` - Go to declaration
- `gy` - Go to type definition
- `gs` - Signature help
- `g0` - Show diagnostics in location list
- `grc` - Run code lens
- `grh` - Toggle inlay hints
- `gK` - Toggle diagnostic virtual lines
- `<leader>wn/wd/wl` - Add/remove/list workspace folders

### Folding
- `<leader><space>` - Toggle fold

## Common Development Commands

### Plugin Management
```vim
:lua require('packman').install()     " Install all plugins from packfile
:lua require('packman').get('repo')   " Install single plugin
:lua require('packman').update()      " Update all plugins
:lua require('packman').list()        " List installed plugins
:lua require('packman').remove()      " Remove plugin
:lua require('packman').dump()        " Generate packfile from installed
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
:TSInfo                                " Show parser info
```

### File Operations
```vim
:Oil                                   " Open oil file browser
:Gitsigns                              " Git operations (diff, blame, etc.)
```

## Configuration Notes

- Uses space as leader key
- Default shell is nushell (`nu`)
- Spell checking enabled (English US)
- Uses system clipboard on macOS only
- Folding enabled with treesitter
- Diagnostic virtual text disabled, only virtual lines for current line

### Auto-save Behavior
Auto-save is configured in `lua/autocmds.lua` with the following characteristics:
- Triggered on `InsertLeave` and `TextChanged` events
- Uses a 500ms debounce delay
- Checks for Treesitter syntax errors before saving
- Won't save unnamed, unmodified, readonly, or special buffers

### Important Options
- `virtualedit = 'block,onemore'` - Allow cursor past end of line
- `wrapscan = false` - Search stops at end of file (doesn't wrap)
- `hidden = true` - Hide changed buffers instead of closing
- `confirm = true` - Ask confirmation when quitting with unsaved changes
- `updatetime = 30` - Fast updates for lualine
- `lazyredraw = true` - Performance optimization

## File Structure
```
.
├── init.lua                    # Main entry point
├── lua/
│   ├── options.lua            # Neovim options
│   ├── keymaps.lua            # Keyboard mappings
│   ├── autocmds.lua           # Auto commands
│   ├── ui.lua                 # UI configuration
│   ├── packman.lua            # Plugin manager
│   ├── packfile               # Plugin definitions
│   └── plugins/               # Plugin configurations
│       ├── init.lua           # Plugin loader
│       ├── lsp.lua            # LSP setup
│       ├── treesitter.lua     # Syntax highlighting
│       └── ...                # Other plugin configs
└── pack/
    └── packman/               # Plugin installation directory
        ├── start/             # Auto-loaded plugins
        └── opt/               # Optional plugins
```
