# AGENTS.md

Guidance for coding agents working in this repository. Paths are relative to the repository root.

Better Start Nvim is a minimalist Lua configuration for Neovim 0.12+ using built-in `vim.pack`.
Its long-term goal is reusable boilerplate with no third-party Neovim plugin
dependencies. The current checkout still loads configured packages.

## Documentation

Keep module and feature documentation in `doc/` as native Vim help (`.txt`).
Use namespaced `better-start-nvim-*` tags and link guides from `:help better-start-nvim`.
Keep `README.md` and `AGENTS.md` at the repository root. Write self-contained
descriptions and use Vim key notation such as `<leader>p`.
Leave `README.md` unchanged unless the user explicitly requests edits to it.

Document first-party Better Start Nvim modules and native Neovim behavior.
Do not add third-party Neovim plugin setup, usage, or build guides, or plugin
dependency inventories.

Read the relevant source before changing behavior or bindings; avoid duplicating option values and keymap inventories here.

- `doc/better-start-nvim.txt` - Help index and installation
- `doc/better_statusline.txt` - Native bars, refresh model, and verification
- `doc/better_select.txt` - Picker behavior and verification
- `doc/which-key.txt` - Native prefix hints, input semantics, and verification
- `doc/prelude.txt` - Common utilities and table package API
- `doc/ffi.txt` - Rust library, Lua module API, build, and verification
- `doc/projects-workspaces.txt` - Project and workspace bindings, settings, persistence, and verification

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
- `lua/which_key.lua` - Native Normal/Visual prefix hints
- `lua/projects.lua` - Project commands
- `lua/workspaces.lua` - Named tab workspaces and session snapshots
- `lua/workspace_store.lua` - JSON persistence and selection lists
- `lsp/*.lua` - Native LSP server configurations

### Native Packages

- Neovim loads `after/plugin/*.lua` directly during native plugin startup. Native `--noplugin` skips these scripts. The colorscheme in `lua/ui.lua` is the sole exception.
- The repository's `vim.pack.use { 'module', from = URL, build = argv }` extension adds a package, completes required builds, and returns its optional module. Native `load`/`confirm` options are supported; there is no `config` callback. See `doc/prelude.txt` for the API and build lifecycle. Native `vim.pack.add` remains available.
- `after/plugin/lsp.lua` defines LSP activation and attachment mappings. Check it alongside `lua/keymaps.lua` when changing bindings.
- `nvim-pack-lock.json` pins package revisions.

## Verification

Run from the repository root. Build the Rust library before running the statusline
and native Git tests. The workspace tests isolate persistence in temporary directories.

```sh
cargo build --release
nvim --headless -u NONE -i NONE -l tests/ffi_git.lua
nvim --headless -u NONE -i NONE -l tests/better_statusline.lua
nvim --headless -u NONE -i NONE -l tests/prelude.lua
nvim --headless -u NONE -i NONE -l tests/workspaces.lua
nvim --headless -u NONE -i NONE -l tests/workspaces_restart.lua
nvim --headless -u NONE -i NONE -l tests/workspaces_review.lua
nvim --headless -u NONE -i NONE -l tests/better_select.lua
nvim --headless -u NONE -i NONE -l tests/completion.lua
nvim --headless -u NONE -i NONE -l tests/pairs.lua
nvim --headless -u NONE -i NONE -l tests/fff.lua
nvim --headless -u NONE -i NONE -l tests/which_key.lua
nvim --headless -u NONE -i NONE -l tests/which_key_ui.lua
nvim --headless -u NONE -i NONE -l tests/which_key_bench.lua
```

Run keyboard/UI tests in an attached terminal:

```sh
nvim -u NONE -i NONE -c 'luafile tests/workspaces_ui.lua'
nvim -u NONE -i NONE -c 'luafile tests/better_select_ui.lua'
```

`tests/startup.lua` exercises the full configuration and installed plugins. For isolated startup checks, set `XDG_CACHE_HOME`, `XDG_STATE_HOME`, and `NVIM_LOG_FILE` to temporary locations, then run `nvim --headless -u ./init.lua -i NONE -c 'luafile tests/startup.lua'`. Full startup can install missing configured plugins; use the `-u NONE` tests when plugin loading is unnecessary.
