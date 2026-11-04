# Common utilities

`lua/prelude.lua` is loaded by `init.lua` before other configuration modules.
It extends native `vim.pack` with a single table declaration API and synchronous
install/update builds. It requires Neovim 0.12+ with native `vim.pack`.

```lua
vim.pack.use {
        'colorizer',
        from = 'https://github.com/catgoose/nvim-colorizer.lua',
}.setup()

vim.pack.use {
        'blink.pairs',
        from = 'https://github.com/saghen/blink.pairs',
        build = { 'cargo', 'build', '--release', '--locked' },
}.setup {}

-- Script-only packages omit the module name.
vim.pack.use {
        from = 'https://github.com/eraserhd/parinfer-rust',
        build = { 'cargo', 'build', '--release' },
}
```

Call `vim.pack.use(spec)` with a table containing a required non-empty package
URL in `from`. The optional index `1` is a non-empty Lua module name to require
and return after adding the package and completing any required build. Omit it
for script-only packages. There is no `src` alias or `config` callback;
unknown fields are rejected. The other optional fields are:

- `name`, `version`, and `data`: native package specification fields.
- `load` and `confirm`: native add options. `load` accepts a boolean or native
  loading callback; `confirm` accepts a boolean. Omitted or nil values preserve
  native defaults, including installation confirmation.
- `build`: a non-empty list of string arguments, copied when declared.

The declaration returns the result of `require(spec[1])`, or nil when no module
is supplied. Configure the returned module directly, or assign it to a local
variable when later callbacks need it. Native add, build, and require errors
propagate to the caller. Native version selection and Lua's module cache still
apply; repeated declarations use the cached module rather than reloading it.

Omitted `load` preserves native behavior: plugin scripts are deferred while
initialization is in progress and loaded immediately afterward. `load = true`
loads scripts immediately; `load = false` skips their loading for that call.
A supplied module is required even with `load = false`; that option controls
native plugin scripts and does not defer the module or its setup.

Build commands run synchronously in the package directory without a shell.
The prelude records install/update events, including packages restored from the
lockfile before their own declaration. A declaration registers its build before
native add, so a pending restored install is built before that add can load
plugin scripts. Newly installed packages build during their `PackChanged` event,
before native loading. Once registered, later install/update events run the
command immediately without requiring the module or repeating setup. Packages
already installed without a pending event are not rebuilt on startup.

A nonzero exit raises an error containing the package name and captured stderr
(or stdout when stderr is unavailable). The event remains pending so declaring
the build again retries it. A failed pending build stops the declaration before
native add; native add and build errors prevent requiring the module. Delete
events clear pending work without running a build. Build registrations last for
the current session. Build matching uses native name normalization: the final
path component of explicit `name`, or of the URL after removing a trailing `.git`.

The prelude rejects an existing `vim.pack.use` field, including `false`, before
changing the API or any build hook. An explicit prelude reload therefore fails;
ordinary repeated `require 'prelude'` calls use Lua's cache.

Plugin scripts under `after/plugin/` declare packages beside their configuration.
Neovim loads these scripts directly during native plugin startup; native
`--noplugin` skips them. Script-only packages and packages whose Lua modules
should stay deferred can use native `vim.pack.add`.
Packages added during this phase may miss their own `after/plugin/` scripts.
For example, indent-blankline setup runs, but its `IBL*` commands are not registered.
Completion wraps the startup Enter and Right mappings once at `VimEnter`, after
Blink pairing setup has installed its Enter mapping. Either configuration script
can run first, provided both finish before that event. See [Completion](completion.md)
for fallback behavior and timing constraints.
Cargo builds for blink.pairs, parinfer-rust, and vim-markdown-composer require
Cargo (nightly Rust for blink.pairs). fff.nvim keeps its custom `PackChanged` hook
because it calls the plugin's Lua download-or-build helper.

Verify without downloading plugins or running Cargo:

```sh
nvim --headless -u NONE -i NONE -l tests/prelude.lua
```
