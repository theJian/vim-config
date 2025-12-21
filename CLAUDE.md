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
- Plugin definitions are stored in `lua/packfile`
- Use `:lua require('packman').install()` to install from packfile
- Use `:lua require('packman').get('user/repo')` to install single plugins
- Use `:lua require('packman').update()` to update plugins
- Use `:lua require('packman').list()` to list installed plugins

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

## Common Development Commands

### Plugin Management
```vim
:lua require('packman').install()     " Install all plugins from packfile
:lua require('packman').get('repo')  " Install single plugin
:lua require('packman').update()     " Update all plugins
:lua require('packman').list()       " List installed plugins
:lua require('packman').remove()     " Remove plugin
```

### LSP Operations
```vim
:LspInfo          " Show attached LSP servers
:lua vim.lsp.buf.format()  " Format current buffer
:lua vim.lsp.buf.rename()  " Rename symbol
:lua vim.lsp.buf.code_action()  " Code actions
```

### Mason (LSP Server Management)
```vim
:Mason            " Open Mason UI
:MasonInstall <server>  " Install LSP server
:MasonUninstall <server> " Uninstall LSP server
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
:TSInstall <language>    " Install treesitter parser
:TSUninstall <language>  " Uninstall parser
:TSInfo                   " Show parser info
```

### File Operations
```vim
:Oil                      " Open oil file browser
:Gitsigns                 " Git operations (diff, blame, etc.)
```

## Configuration Notes

- Uses space as leader key
- Default shell is nushell (`nu`)
- Spell checking enabled (English US)
- Uses system clipboard on macOS
- Folding enabled with treesitter
- Auto-save on certain events (configured in autocmds)
- Diagnostic virtual text disabled, only virtual lines for current line

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
