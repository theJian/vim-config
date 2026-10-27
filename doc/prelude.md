# Common utilities

`lua/prelude.lua` is loaded by `init.lua` before other configuration modules.
It extends native `vim.pack` with a fluent package API:

The prelude raises `prelude: vim.pack.load already exists` if `vim.pack.load` is
not nil, before changing any functions or build hooks. This also applies to an
explicit reload; ordinary repeated `require 'prelude'` calls use Lua's cache.

```lua
vim.pack.load 'https://github.com/stevearc/oil.nvim.git'
        .using 'oil'
        .setup {}

vim.pack.load 'https://github.com/saghen/blink.pairs'
        .build { 'cargo', 'build', '--release', '--locked' }
        .using 'blink.pairs'
        .setup {}
```

- `vim.pack.load(source)` accepts a URL string or `vim.pack.Spec`, calls
  `vim.pack.add`, and returns a package handle. Native installation confirmation,
  version selection, and plugin loading defaults apply.
- `.build(command)` registers an argv list for that package's install and update
  `PackChanged` events, and returns the same handle. Commands run synchronously
  in the package directory, without a shell. A nonzero exit raises an error with
  the package name and command output. Registering again replaces the command.
- `.using(module)` returns Lua's `require(module)` result, preserving its module
  cache and errors. Subsequent calls such as `.setup` belong to that module.

Use dot calls, not colon calls. A spec's explicit `name` is respected when
matching build events; otherwise the repository basename without `.git` is used.

The prelude records install/update events, including packages restored from the
lockfile before their own declaration. When `.build` is first registered, any
pending event is built immediately, before the following `.using` call. Native
plugin scripts may already have run during `load`; packages that need compilation
before their `plugin/` scripts execute still need a hook registered before adding
them. Unchanged installed packages are not rebuilt on startup. Build failures
remain pending so registering the build again retries them. Delete events do not
build. Build registrations last for the current Neovim session.

Plugin modules under `lua/plugins/` declare their own packages beside setup,
with dependencies loaded first. Simple standalone plugins live in the entry
point, `lua/plugins/init.lua`. Cargo builds for blink.pairs, parinfer-rust, and
vim-markdown-composer use `.build`; parinfer-rust now waits for compilation and
reports failures. fff.nvim keeps its custom `PackChanged` hook because it calls
the plugin's Lua download-or-build helper rather than an external command.

Verify without downloading plugins or running Cargo:

```sh
nvim --headless -u NONE -i NONE -l tests/prelude.lua
```
