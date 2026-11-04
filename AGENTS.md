# AGENTS.md

Guidance for coding agents working in this repository. Paths are relative to the repository root.

This is a minimalist Lua configuration for Neovim 0.12+ using built-in `vim.pack`.

## Documentation

Keep module and feature documentation in `doc/`. Keep `README.md` and `AGENTS.md` at the repository root. Write self-contained descriptions and use Vim key notation such as `<leader>p`.

Read the relevant source before changing behavior or bindings; avoid duplicating option values, keymap inventories, and plugin usage instructions here.

- `doc/better_statusline.md` - Native bars, refresh model, and verification
- `doc/better_select.md` - Picker behavior and verification
- `doc/prelude.md` - Common utilities and table package API
- `doc/completion.md` - Native completion and pairing mapping composition
- `doc/projects-workspaces.md` - Project and workspace bindings, settings, persistence, and verification

## Architecture

### Core Structure

- `init.lua` - Loads core modules
- `lua/prelude.lua` - Common utilities and native package extensions
- `lua/options.lua` - Editor options
- `lua/keymaps.lua` - Keyboard mappings and leader setup
- `lua/autocmds.lua` - Automatic behavior, including auto-save
- `after/plugin/*.lua` - Native plugin configuration scripts
- `lua/ui.lua` - UI options and colorscheme installation and setup
- `lua/better_statusline.lua` - Cached native statusline, window bars, and tabline
- `lua/better_select.lua` - Native ui2 picker
- `lua/projects.lua` - Project commands
- `lua/workspaces.lua` - Named tab workspaces and session snapshots
- `lua/workspace_store.lua` - JSON persistence and selection lists
- `lsp/*.lua` - Native LSP server configurations

### Plugins

- Neovim loads `after/plugin/*.lua` directly during native plugin startup. Native `--noplugin` skips these scripts. The colorscheme in `lua/ui.lua` is the sole exception.
- Declare packages beside their configuration under `after/plugin/` using `vim.pack.use { 'module', from = URL, build = argv }.setup {}` with optional `build` and native `load`/`confirm` options. The declaration adds the package, completes required builds, and returns the required module; assign it to a local when needed by later callbacks. Omit the module for script-only packages that need a build. There is no `config` callback. Native `vim.pack.add` remains available for script-only packages or deferred Lua modules. Put standalone declarations in their own plugin scripts. fff.nvim retains a custom download-or-build hook.
- `after/plugin/lsp.lua` defines LSP activation and attachment mappings. Check it alongside `lua/keymaps.lua` when changing bindings.
- `nvim-pack-lock.json` pins plugin revisions. Missing packages install automatically; native build hooks require Cargo (nightly Rust for blink.pairs).

## Verification

Run from the repository root. The workspace tests isolate persistence in temporary directories.

```sh
nvim --headless -u NONE -i NONE -l tests/better_statusline.lua
nvim --headless -u NONE -i NONE -l tests/prelude.lua
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
